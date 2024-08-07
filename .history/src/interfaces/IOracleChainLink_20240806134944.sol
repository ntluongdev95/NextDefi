// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IOracleChainLink {
    function getPrice(address token) external view returns (int256, uint8);
    function getPriceIn1e18(address token) external view returns (int256);
    function addTokenPriceFeed(address token, address feed) external;
    function addTokenMaxDelay(address token, uint256 maxDelay) external ;
    function addTokenMaxDeviation(address token, uint256 maxDeviation) external;
    function emergencyPause() external ;

}