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
import{IWNT} from "../interfaces/IWNT.sol";
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
  event PerformanceFeeUpdated(
    address indexed caller,
    uint256 previousPerformanceFee,
    uint256 newPerformanceFee
  );
  event UpdateMaxCapacity(uint256 maxCapacity);
  event EmergencyShutdown(address indexed caller);
  event EmergencyResume(address indexed caller);
  event UpdateInterestRate(
    uint256 baseRate,
    uint256 multiplier,
    uint256 jumpMultiplier,
    uint256 kink1,
    uint256 kink2
  );
  event UpdateMaxInterestRate(
    uint256 baseRate,
    uint256 multiplier,
    uint256 jumpMultiplier,
    uint256 kink1,
    uint256 kink2
  );


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

    /* ================== MUTATIVE FUNCTIONS =================== */

    function depositNative(uint256 assetAmt, uint256 minSharesAmt) external payable nonReentrant whenNotPaused{
        if(msg.value == 0) revert Errors.EmptyDepositAmount();
        if(msg.value != assetAmt) revert Errors.InvalidNativeDepositAmountValue();
        if(totalAsset() + assetAmt > maxCapacity) revert Errors.InsufficientCapacity();
        if (assetAmt == 0) revert Errors.InsufficientDepositAmount();
        IWNT(address(asset)).deposit{ value: msg.value }();
         _updateVaultWithInterestsAndTimestamp(assetAmt);
          uint256 _sharesAmount = _mintShares(assetAmt);

    if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

    emit Deposit(msg.sender, _sharesAmount, assetAmt);
    }

    function deposit (uint256 assetAmt, uint256 minSharesAmt) external nonReentrant whenNotPaused {
        if (assetAmt == 0) revert Errors.InsufficientDepositAmount();
        if (totalAsset() + assetAmt > maxCapacity) revert Errors.InsufficientCapacity();
        asset.safeTransferFrom(msg.sender, address(this), assetAmt);
        _updateVaultWithInterestsAndTimestamp(assetAmt);
        uint256 _sharesAmount = _mintShares(assetAmt);

        if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

        emit Deposit(msg.sender, _sharesAmount, assetAmt);
    }

    function borrow(uint256 borrowAmt) external nonReentrant WhenNotPaused {

    }
     /* ================== INTERNAL FUNCTIONS =================== */
     function _pendingInterest(uint256 assetAmt) internal view returns (uint256) {
      if(totalBorrows == 0) return 0;
      uint256 _totalAvailableAsset = totalAvailableAsset();
      uint256 _timePassed = block.timestamp - lastUpdatedAt;
      uint256 _floating = _totalAvailableAsset == 0 ? 0 : _totalAvailableAsset - assetAmt;
    uint256 _ratePerSec = _calculateInterestRate(totalBorrows, _floating) / SECONDS_PER_YEAR;

    // First division is due to _ratePerSec being in 1e18
    // Second division is due to _ratePerSec being in 1e18
    return _ratePerSec * totalBorrows * _timePassed / SAFE_MULTIPLIER;
     }

     function _calculateInterestRate(uint256 _debt,uint256 _floating) internal view returns (uint256){
       if(_debt ==0 && _floating == 0) return 0;
       uint256 _total  = _debt +_floating;
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

      return 10**(18 - ERC20(address(asset)).decimals());
    }
  }

   function _updateVaultWithInterestsAndTimestamp(uint256 assetAmt) internal {
    uint256 _interest = _pendingInterest(assetAmt);
    uint256 _toReserve = _interest * performanceFee / SAFE_MULTIPLIER;

    vaultReserves = vaultReserves + _toReserve;
    totalBorrows = totalBorrows + _interest;
    
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


  
       
}
