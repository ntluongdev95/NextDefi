// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwap} from "../interfaces/ISwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IOracleChainLink} from "../interfaces/IOracleChainLink.sol";
import {Errors} from "../utils/Errors.sol";
contract USwap is Ownable, ISwap {
    using SafeERC20 for IERC20;

    ISwapRouter public router;
    IOracleChainLink public oracle;

    constructor (ISwapRouter _router, IOracleChainLink _oracle) Ownable(msg.sender) {
        if(address(_router )== address(0) || address(_oracle) ==address(0)) revert Errors.ZeroAddressNotAllowed();

        router = ISwapRouter(_router);
        oracle = IOracleChainLink(_oracle);
    }
      /* ================== MUTATIVE FUNCTIONS =================== */
    /**
    * @notice Swap exact amount of tokenIn for as many amount of tokenOut
    * @param sp ISwap.SwapParams
    * @return amountOut Amount of tokens out; in token decimals
    *  struct SwapParams {
        // Address of token in
        address tokenIn;
        // Address of token out
        address tokenOut;
        // Amount of token in; in token decimals
        uint256 amountIn;
        // Amount of token out; in token decimals
        uint256 amountOut;
        // Slippage tolerance swap; e.g. 3 = 0.03%
        uint256 slippage;
        // Swap deadline timestamp
        uint256 deadline;
    }
  */
    function swapExactTokensForTokens(ISwap.SwapParams memory sp) external returns (uint256) {
        if(sp.tokenIn == address(0) || sp.tokenOut == address(0)) revert Errors.ZeroAddressNotAllowed();
        if(sp.amountIn == 0) revert Errors.EmptyDepositAmount();
        if(sp.deadline < block.timestamp) revert Errors.EmptyDepositAmount();
        IERC20(sp.tokenIn).safeTransferFrom(msg.sender, address(this), sp.amountIn);
        IERC20(sp.tokenIn)
       
    }

}
