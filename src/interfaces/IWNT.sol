// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IWNT {
    function balanceOf(address user) external returns (uint256);
    function approve(address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
