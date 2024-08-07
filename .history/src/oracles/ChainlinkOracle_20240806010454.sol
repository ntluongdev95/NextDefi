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
    error TokenPriceFeedMaxDeviationMustBeGreaterOrEqualToZero()

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

  /**
    * @notice Checks to see if Chainlink oracle is returning a bad response
    * @param response Chainlink response
    * @return Status of check in boolean
  */
  function _badChainlinkResponse(ChainlinkResponse memory response) internal view returns (bool) {
    // Check for response call reverted
    if (!response.success) { return true; }
    // Check for an invalid roundId that is 0
    if (response.roundId == 0) { return true; }
    // Check for an invalid timeStamp that is 0, or in the future
    if (response.timestamp == 0 || response.timestamp > block.timestamp) { return true; }
    // Check for non-positive price
    if (response.answer == 0) { return true; }

    return false;
  }
  /**
    * @notice Check to see if Chainlink oracle response is frozen/too stale
    * @param response Chainlink response
    * @param token Token address
    * @return Status of check in boolean
  */
  function _chainlinkIsFrozen(ChainlinkResponse memory response, address token) internal view returns (bool) {
    return (block.timestamp - response.timestamp) > maxDelays[token];
  }
  /**
    * @notice Check to see if Chainlink oracle current response's price price deviation
    * is too large compared to previous response's price
    * @param currentResponse Current Chainlink response
    * @param prevResponse Previous Chainlink response
    * @param token Token address
    * @return Status of check in boolean
  */
  function _badPriceDeviation(
    ChainlinkResponse memory currentResponse,
    ChainlinkResponse memory prevResponse,
    address token
  ) internal view returns (bool) {
    // Check for a deviation that is too large
    uint256 _deviation;

    if (currentResponse.answer > prevResponse.answer) {
      _deviation = uint256(currentResponse.answer - prevResponse.answer) * SAFE_MULTIPLIER / uint256(prevResponse.answer);
    } else {
      _deviation = uint256(prevResponse.answer - currentResponse.answer) * SAFE_MULTIPLIER / uint256(prevResponse.answer);
    }

    return _deviation > maxDeviations[token];
  }
   /* ================= RESTRICTED FUNCTIONS ================== */

  /**
    * @notice Add Chainlink price feed for token
    * @param token Token address
    * @param feed Chainlink price feed address
    */
  function addTokenPriceFeed(address token, address feed) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feed == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] != address(0)) revert Errors.TokenPriceFeedAlreadySet();

    feeds[token] = feed;
  }

  /**
    * @notice Add Chainlink max delay for token
    * @param token Token address
    * @param maxDelay  Max delay allowed in seconds
  */
  function addTokenMaxDelay(address token, uint256 maxDelay) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] == address(0)) revert Errors.NoTokenPriceFeedAvailable();
    if (maxDelay < 0) revert Errors.TokenPriceFeedMaxDelayMustBeGreaterOrEqualToZero();

    maxDelays[token] = maxDelay;
  }

  /**
    * @notice Add Chainlink max deviation for token
    * @param token Token address
    * @param maxDeviation  Max deviation allowed in seconds
  */
  function addTokenMaxDeviation(address token, uint256 maxDeviation) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] == address(0)) revert InvalidFeed() ;
    if (maxDeviation < 0) revert TokenPriceFeedMaxDeviationMustBeGreaterOrEqualToZero();

    maxDeviations[token] = maxDeviation;
  }

  /**
    * @notice Emergency pause of this oracle
  */
  function emergencyPause() external onlyOwner whenNotPaused {
    _pause();
  }

  /**
    * @notice Emergency resume of this oracle
  */
  function emergencyResume() external onlyOwner whenPaused {
    _unpause();
  }
}