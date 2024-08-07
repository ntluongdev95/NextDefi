// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwap} from "../interfaces/ISwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IOracleChainLink} from "../interfaces/IOracleChainLink.sol";

contract USwap is Ownable, ISwap {
    using SafeERC20 for IERC20;

    ISwapRouter public router;
    IOracleChainLink public oracle;

    constructor (ISwapRouter _router, IOracleChainLink _oracle) Ownable(msg.sender) {
        if(address(_router == address(0)) ||)
        router = ISwapRouter(_router);
        oracle = IOracleChainLink(_oracle);
    }

}
