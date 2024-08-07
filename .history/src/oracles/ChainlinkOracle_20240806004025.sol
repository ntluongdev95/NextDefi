// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import { AggregatorV3Interface } from "@chainlink/src/interfaces/feeds/AggregatorV3Interface.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract ChainlinkOracle is Ownable2Step, Pausable {

    using SafeCast for int256;

    struct ChainlinkResponse {
    uint80 roundId;
    int256 answer;
    uint256 timestamp;
    bool success;
    uint8 decimals;
  }
   
    // Mapping of token to Chainlink USD price feed
  mapping(address => address) public feeds;
  // Mapping of token to maximum delay allowed (in seconds) of last price update
  mapping(address => uint256) public maxDelays;
  // Mapping of token to maximum % deviation allowed (in 1e18) of last price update
  mapping(address => uint256) public maxDeviations;

    constructor() Ownable(msg.sender) {}

    /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * @notice Get token price from Chainlink feed
    * @param token Token address
    * @return price Asset price in int256
    * @return decimals Price decimals in uint8
    */
   function getPrice( address token) public view whenNotPaused returns (int256, uint8) {
     if(token == address(0)) revert ZeroAddressNotAllowed();
     address feed = feeds[token];
     if()
   }

}