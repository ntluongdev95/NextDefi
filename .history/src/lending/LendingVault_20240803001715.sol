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
import { Errors } from "../utils/Errors.sol";

contract LendingVault is ERC20, ReentrancyGuard, Pausable, Ownable2Step, ILendingVault {
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

    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        bool isNativeAsset_,
        uint256 maxCapacity_,
        InterestRate memory interestRate_,
        InterestRate memory maxInterestRate_,
        uint256 performanceFee_,
        address treasury_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (address(asset_) == address(0)) revert Errors.ZeroAddressNotAllowed();
         if (_treasury == address(0)) revert Errors.ZeroAddressNotAllowed();
         if(IERC20(asset_).decimals() > 18) revert Errors.TokenDecimalsMustBeLessThan18();
        asset = IERC20(asset_);
        isNativeAsset = isNativeAsset_;
        maxCapacity = maxCapacity_;
        interestRate = interestRate_;
        maxInterestRate = maxInterestRate_;
        performanceFee = performanceFee_;
        treasury = treasury_;
    }
}
