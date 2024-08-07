// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library Errors {
    /* ======================== GENERAL ======================== */

    error ZeroAddressNotAllowed();
    error TokenDecimalsMustBeLessThan18();

    /* ===================== VAULT DEPOSIT ===================== */

  error EmptyDepositAmount();
  error InvalidDepositToken();
  error InsufficientDepositAmount();
  error InvalidNativeDepositAmountValue();
  error InsufficientSharesMinted();
  error InsufficientCapacity();
  error OnlyNonNativeDepositToken();
  error InvalidNativeTokenAddress();
  error DepositAndExecutionFeeDoesNotMatchMsgValue();
  error DepositCancellationCallback();
  error OnlyBorrowerAllowed()

}
