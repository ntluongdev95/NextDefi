// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ILendingVault {
     struct Borrower {
    // Boolean for whether borrower is approved to borrow from this vault
    bool approved;
    // Debt share of the borrower in this vault
    uint256 debt;
    // The last timestamp borrower borrowed from this vault
    uint256 lastUpdatedAt;
  }

struct InterestRate{
     // Base interest rate which is the y-intercept when utilization rate is 0 in 1e18
    uint256 baseRate;
     // Multiplier of utilization rate that gives the slope of the interest rate in 1e18
    uint256 multiplier;
    // Multiplier after hitting a specified utilization point (kink2) in 1e18
    uint256 jumpMultiplier;
    // Utilization point at which the interest rate is fixed in 1e18
    uint256 kink1;
    // Utilization point at which the jump multiplier is applied in 1e18
    uint256 kink2;
}
    
}