// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import { AggregatorV3Interface } from "@chainlink/src/interfaces/feeds/AggregatorV3Interface.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract ChainlinkOracle is Ownable2Step, Pausable {

    using SafeCast for int256;

    error  InvalidFeed();

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
     if(feed == address(0))  revert InvalidFeed();
     
   }


   ///////////////INTERNAL FUNCTIONS////////////// 

   function _getChainlinkResponse(address feed) internal view returns (ChainlinkResponse memory) {
    ChainlinkResponse memory _chainlinkResponse;

    _chainlinkResponse.decimals = AggregatorV3Interface(_feed).decimals();

     (
      uint80 _latestRoundId,
      int256 _latestAnswer,
      /* uint256 _startedAt */,
      uint256 _latestTimestamp,
      /* uint80 _answeredInRound */
    ) = AggregatorV3Interface(_feed).latestRoundData();

    _chainlinkResponse.roundId = _latestRoundId;
    _chainlinkResponse.answer = _latestAnswer;
    _chainlinkResponse.timestamp = _latestTimestamp;
    _chainlinkResponse.success = true;

    return _chainlinkResponse;

   }
   /**
    * @notice Get previous round's Chainlink response from current round
    * @param _feed Chainlink oracle feed address
    * @param _currentRoundId Current roundId from current Chainlink response
    * @return ChainlinkResponse
  */
  function _getPrevChainlinkResponse(address _feed, uint80 _currentRoundId) internal view returns (ChainlinkResponse memory) {
    ChainlinkResponse memory _prevChainlinkResponse;

    (
      uint80 _roundId,
      int256 _answer,
      /* uint256 _startedAt */,
      uint256 _timestamp,
      /* uint80 _answeredInRound */
    ) = AggregatorV3Interface(_feed).getRoundData(_currentRoundId - 1);

    _prevChainlinkResponse.roundId = _roundId;
    _prevChainlinkResponse.answer = _answer;
    _prevChainlinkResponse.timestamp = _timestamp;
    _prevChainlinkResponse.success = true;

    return _prevChainlinkResponse;
  }
}