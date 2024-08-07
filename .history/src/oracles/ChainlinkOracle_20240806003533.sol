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
  

    constructor() Ownable(msg.sender) {}

}