// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ILendingVault} from "../interfaces/ILendingVault.sol";
import {IWNT} from "../interfaces/IWNT.sol";
import {Errors} from "../utils/Errors.sol";

contract LendingVault is ERC20, ReentrancyGuard, Pausable, Ownable2Step, ILendingVault {
    using SafeERC20 for IERC20;
    /* ====================== CONSTANTS ======================== */

    uint256 public constant SAFE_MULTIPLIER = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /* ==================== STATE VARIABLES ==================== */
    // Vault's underlying asset
    IERC20 public asset;
    // Is asset native ETH
    bool public isNativeAsset;
    // Protocol treasury address
    address public treasury;
    // Amount borrowed from this vault
    uint256 public totalBorrows;
    // Total borrow shares in this vault
    uint256 public totalBorrowDebt;
    // The fee % applied to interest earned that goes to the protocol in 1e18
    uint256 public performanceFee;
    // Protocol earnings reserved in this vault
    uint256 public vaultReserves;
    // Last updated timestamp of this vault
    uint256 public lastUpdatedAt;
    // Max capacity of vault in asset decimals / amt
    uint256 public maxCapacity;
    // Interest rate model
    InterestRate public interestRate;
    // Max interest rate model limits
    InterestRate public maxInterestRate;

    /* ======================= MAPPINGS ======================== */

    // Mapping of borrowers to borrowers struct
    mapping(address => Borrower) public borrowers;
    // Mapping of approved keepers
    mapping(address => bool) public keepers;

    /* ======================== EVENTS ========================= */

    event Deposit(address indexed depositor, uint256 sharesAmt, uint256 depositAmt);
    event Withdraw(address indexed withdrawer, uint256 sharesAmt, uint256 withdrawAmt);
    event Borrow(address indexed borrower, uint256 borrowDebt, uint256 borrowAmt);
    event Repay(address indexed borrower, uint256 repayDebt, uint256 repayAmt);
    event PerformanceFeeUpdated(address indexed caller, uint256 previousPerformanceFee, uint256 newPerformanceFee);
    event UpdateMaxCapacity(uint256 maxCapacity);
    event EmergencyShutdown(address indexed caller);
    event EmergencyResume(address indexed caller);
    event UpdateInterestRate(
        uint256 baseRate, uint256 multiplier, uint256 jumpMultiplier, uint256 kink1, uint256 kink2
    );
    event UpdateMaxInterestRate(
        uint256 baseRate, uint256 multiplier, uint256 jumpMultiplier, uint256 kink1, uint256 kink2
    );

    /* ======================= MODIFIERS ======================= */

    /**
     * @notice Allow only approved borrower addresses
     */
    modifier onlyBorrower() {
        _onlyBorrower();
        _;
    }

    /**
     * @notice Allow only keeper addresses
     */
    modifier onlyKeeper() {
        _onlyKeeper();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        bool isNativeAsset_,
        uint256 maxCapacity_,
        InterestRate memory _interestRate,
        InterestRate memory _maxInterestRate,
        uint256 performanceFee_,
        address treasury_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (address(asset_) == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (treasury_ == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (ERC20(asset_).decimals() > 18) revert Errors.TokenDecimalsMustBeLessThan18();
        asset = IERC20(asset_);
        isNativeAsset = isNativeAsset_;
        maxCapacity = maxCapacity_;
        performanceFee = performanceFee_;
        treasury = treasury_;

        interestRate.baseRate = _interestRate.baseRate;
        interestRate.multiplier = _interestRate.multiplier;
        interestRate.jumpMultiplier = _interestRate.jumpMultiplier;
        interestRate.kink1 = _interestRate.kink1;
        interestRate.kink2 = _interestRate.kink2;

        maxInterestRate.baseRate = _maxInterestRate.baseRate;
        maxInterestRate.multiplier = _maxInterestRate.multiplier;
        maxInterestRate.jumpMultiplier = _maxInterestRate.jumpMultiplier;
        maxInterestRate.kink1 = _maxInterestRate.kink1;
        maxInterestRate.kink2 = _maxInterestRate.kink2;
    }
    /* ===================== VIEW FUNCTIONS ==================== */

    function totalAsset() public view returns (uint256) {
        return totalBorrows + _pendingInterest(0) + totalAvailableAsset();
    }

    function totalAvailableAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

     /**
    * @notice Returns a borrower's maximum total repay amount taking into account ongoing interest
    * @param borrower   Borrower's address
    * @return maxRepay   Borrower's total repay amount of assets in assets decimals
  */
   function maxRepay(address borrower) public view returns (uint256) {
    if (totalBorrows == 0) {
      return 0;
    } else {
      return borrowers[borrower].debt * (totalBorrows + _pendingInterest(0)) / totalBorrowDebt;
    }
  }
     /**
    * @notice Returns the the borrow utilization rate of the vault
    * @return utilizationRate   Ratio of borrows to total liquidity in 1e18
  */
  function utilizationRate() public view returns (uint256){
    uint256 totalAsset_ = totalAsset();

    return (totalAsset_ == 0) ? 0 : totalBorrows * SAFE_MULTIPLIER / totalAsset_;
  }

  /**
    * @notice Returns the exchange rate for lvToken to asset
    * @return lvTokenValue   Ratio of lvToken to underlying asset in token decimals
  */
  function lvTokenValue() public view returns (uint256) {
    uint256 totalAsset_ = totalAsset();
    uint256 totalSupply_ = totalSupply();

    if (totalAsset_ == 0 || totalSupply_ == 0) {
      return 1 * (10 ** ERC20(address(asset)).decimals());
    } else {
      return totalAsset_ * SAFE_MULTIPLIER / totalSupply_;
    }
  }


    /* ================== MUTATIVE FUNCTIONS =================== */

    function depositNative(uint256 assetAmt, uint256 minSharesAmt) external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert Errors.EmptyDepositAmount();
        if (msg.value != assetAmt) revert Errors.InvalidNativeDepositAmountValue();
        if (totalAsset() + assetAmt > maxCapacity) revert Errors.InsufficientCapacity();
        if (assetAmt == 0) revert Errors.InsufficientDepositAmount();
        IWNT(address(asset)).deposit{value: msg.value}();
        _updateVaultWithInterestsAndTimestamp(assetAmt);
        uint256 _sharesAmount = _mintShares(assetAmt);

        if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

        emit Deposit(msg.sender, _sharesAmount, assetAmt);
    }

    function deposit(uint256 assetAmt, uint256 minSharesAmt) external nonReentrant whenNotPaused {
        if (assetAmt == 0) revert Errors.InsufficientDepositAmount();
        if (totalAsset() + assetAmt > maxCapacity) revert Errors.InsufficientCapacity();
        asset.safeTransferFrom(msg.sender, address(this), assetAmt);
        _updateVaultWithInterestsAndTimestamp(assetAmt);
        uint256 _sharesAmount = _mintShares(assetAmt);

        if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

        emit Deposit(msg.sender, _sharesAmount, assetAmt);
    }

    function borrow(uint256 borrowAmt) external nonReentrant whenNotPaused onlyBorrower {
        if (borrowAmt == 0) revert Errors.InsufficientBorrowAmount();
        if (borrowAmt > totalAvailableAsset()) revert Errors.InsufficientLendingLiquidity();
        _updateVaultWithInterestsAndTimestamp(0);
        uint256 _debt = totalBorrows == 0 ? borrowAmt : borrowAmt * totalBorrowDebt / totalBorrows;
        // Update vault state
        totalBorrows = totalBorrows + borrowAmt;
        totalBorrowDebt = totalBorrowDebt + _debt;

        // Update borrower state
        Borrower storage borrower = borrowers[msg.sender];
        borrower.debt = borrower.debt + _debt;
        borrower.lastUpdatedAt = block.timestamp;

        // Transfer borrowed token from vault to manager
        asset.safeTransfer(msg.sender, borrowAmt);

        emit Borrow(msg.sender, _debt, borrowAmt);
    }

    function withdraw(uint256 sharesAmt,uint256 minAssetAmt) public nonReentrant whenNotPaused {
         if (sharesAmt == 0) revert Errors.InsufficientWithdrawAmount();
    if (sharesAmt > balanceOf(msg.sender)) revert Errors.InsufficientWithdrawBalance();

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    uint256 _assetAmt = _burnShares(sharesAmt);

    if (_assetAmt > totalAvailableAsset()) revert Errors.InsufficientAssetsBalance();
    if (_assetAmt < minAssetAmt) revert Errors.InsufficientAssetsReceived();

    if (isNativeAsset) {
      IWNT(address(asset)).withdraw(_assetAmt);
      (bool success, ) = msg.sender.call{value: _assetAmt}("");
      require(success, "Transfer failed.");
    } else {
      asset.safeTransfer(msg.sender, _assetAmt);
    }

    emit Withdraw(msg.sender, sharesAmt, _assetAmt);
    }

    /**
    * @notice Repay asset to lending vault, reducing debt
    * @param repayAmt Amount of debt to repay in token decimals
  */
  function repay(uint256 repayAmt) external nonReentrant {
    if (repayAmt == 0) revert Errors.InsufficientRepayAmount();
    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    uint256 maxRepay_ = maxRepay(msg.sender);
    if (maxRepay_ > 0) {
      if (repayAmt > maxRepay_) {
        repayAmt = maxRepay_;
      }

      // Calculate debt to reduce based on repay amount
      uint256 _debt = repayAmt * borrowers[msg.sender].debt / maxRepay_;

      // Update vault state
      totalBorrows = totalBorrows - repayAmt;
      totalBorrowDebt = totalBorrowDebt - _debt;

      // Update borrower state
      borrowers[msg.sender].debt = borrowers[msg.sender].debt - _debt;
      borrowers[msg.sender].lastUpdatedAt = block.timestamp;

      // Transfer repay tokens to the vault
      asset.safeTransferFrom(msg.sender, address(this), repayAmt);

      emit Repay(msg.sender, _debt, repayAmt);
    }
  }

    /* ================== INTERNAL FUNCTIONS =================== */

    function _onlyBorrower() internal view {
        if (!borrowers[msg.sender].approved) revert Errors.OnlyBorrowerAllowed();
    }

    /**
     * @notice Allow only keeper addresses
     */
    function _onlyKeeper() internal view {
        if (!keepers[msg.sender]) revert Errors.OnlyKeeperAllowed();
    }
    /**
     * @notice Returns the pending interest that will be accrued to the reserves in the next call
     * @param assetAmt Newly deposited assets to be subtracted off total available liquidity in token decimals
     * @return interest  Amount of interest owned in token decimals
     */

    function _pendingInterest(uint256 assetAmt) internal view returns (uint256) {
        if (totalBorrows == 0) return 0;
        uint256 _totalAvailableAsset = totalAvailableAsset();
        uint256 _timePassed = block.timestamp - lastUpdatedAt;
        uint256 _floating = _totalAvailableAsset == 0 ? 0 : _totalAvailableAsset - assetAmt;
        uint256 _ratePerSec = _calculateInterestRate(totalBorrows, _floating) / SECONDS_PER_YEAR;

        // First division is due to _ratePerSec being in 1e18
        // Second division is due to _ratePerSec being in 1e18
        return _ratePerSec * totalBorrows * _timePassed / SAFE_MULTIPLIER;
    }

    function _calculateInterestRate(uint256 _debt, uint256 _floating) internal view returns (uint256) {
        if (_debt == 0 && _floating == 0) return 0;
        uint256 _total = _debt + _floating;
        uint256 _utilization = _total == 0 ? 0 : _debt * SAFE_MULTIPLIER / _total;
        // If _utilization above kink2, return a higher interest rate
        // (base + rate + excess _utilization above kink 2 * jumpMultiplier)
        if (_utilization > interestRate.kink2) {
            return interestRate.baseRate + (interestRate.kink1 * interestRate.multiplier / SAFE_MULTIPLIER)
                + ((_utilization - interestRate.kink2) * interestRate.jumpMultiplier / SAFE_MULTIPLIER);
        }
        // If _utilization between kink1 and kink2, rates are flat
        if (interestRate.kink1 < _utilization && _utilization <= interestRate.kink2) {
            return interestRate.baseRate + (interestRate.kink1 * interestRate.multiplier / SAFE_MULTIPLIER);
        }

        // If _utilization below kink1, calculate borrow rate for slope up to kink 1
        return interestRate.baseRate + (_utilization * interestRate.multiplier / SAFE_MULTIPLIER);
    }

    /**
     * @notice Conversion factor for tokens with less than 1e18 to return in 1e18
     * @return conversionFactor  Amount of decimals for conversion to 1e18
     */
    function _to18ConversionFactor() internal view returns (uint256) {
        unchecked {
            if (ERC20(address(asset)).decimals() == 18) return 1;

            return 10 ** (18 - ERC20(address(asset)).decimals());
        }
    }
    /**
     * @notice Interest accrual function that calculates accumulated interest from lastUpdatedTimestamp and add to totalBorrows
     * @param assetAmt Additonal amount of assets being deposited in token decimals
     */

    function _updateVaultWithInterestsAndTimestamp(uint256 assetAmt) internal {
        uint256 _interest = _pendingInterest(assetAmt);
        uint256 _toReserve = _interest * performanceFee / SAFE_MULTIPLIER;

        vaultReserves = vaultReserves + _toReserve;
        totalBorrows = totalBorrows + _interest;
        lastUpdatedAt = block.timestamp;
    }

    function _mintShares(uint256 assetAmt) internal returns (uint256) {
        uint256 _shares;

        if (totalSupply() == 0) {
            _shares = assetAmt * _to18ConversionFactor();
        } else {
            _shares = assetAmt * totalSupply() / (totalAsset() - assetAmt);
        }

        // Mint lvToken to user equal to liquidity share amount
        _mint(msg.sender, _shares);

        return _shares;
    }
     /**
    * @notice Calculate amount of asset owed to depositor based on lvTokens burned
    * @param sharesAmt Amount of shares to burn in 1e18
    * @return withdrawAmount  Amount of assets withdrawn based on lvTokens burned in token decimals
  */
  function _burnShares(uint256 sharesAmt) internal returns (uint256) {
    // Calculate amount of assets to withdraw based on shares to burn
    uint256 totalSupply_ = totalSupply();
    uint256 _withdrawAmount = totalSupply_ == 0 ? 0 : sharesAmt * totalAsset() / totalSupply_;

    // Burn user's lvTokens
    _burn(msg.sender, sharesAmt);

    return _withdrawAmount;
  }
}
