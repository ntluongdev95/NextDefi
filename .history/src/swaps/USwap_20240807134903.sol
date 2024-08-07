// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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

    uint256 public constant SAFE_MULTIPLIER = 1e18;

    // Mapping of fee tier for tokenIn => tokenOut which determines swap pool
    mapping(address => mapping(address => uint24)) public fees;

    constructor(ISwapRouter _router, IOracleChainLink _oracle) Ownable(msg.sender) {
        if (address(_router) == address(0) || address(_oracle) == address(0)) revert Errors.ZeroAddressNotAllowed();

        router = ISwapRouter(_router);
        oracle = IOracleChainLink(_oracle);
    }
    /* ================== MUTATIVE FUNCTIONS =================== */
    /**
     * @notice Swap exact amount of tokenIn for as many amount of tokenOut
     * @param sp ISwap.SwapParams
     * @return amountOut Amount of tokens out; in token decimals
     *  struct SwapParams {
     *     // Address of token in
     *     address tokenIn;
     *     // Address of token out
     *     address tokenOut;
     *     // Amount of token in; in token decimals
     *     uint256 amountIn;
     *     // Amount of token out; in token decimals
     *     uint256 amountOut;
     *     // Slippage tolerance swap; e.g. 3 = 0.03%
     *     uint256 slippage;
     *     // Swap deadline timestamp
     *     uint256 deadline;
     * }
     */

    function swapExactTokensForTokens(ISwap.SwapParams memory sp) external returns (uint256) {
        if (sp.tokenIn == address(0) || sp.tokenOut == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (sp.amountIn == 0) revert Errors.EmptyDepositAmount();
        if (sp.deadline < block.timestamp) revert Errors.EmptyDepositAmount();
        IERC20(sp.tokenIn).safeTransferFrom(msg.sender, address(this), sp.amountIn);
        IERC20(sp.tokenIn).approve(address(router), sp.amountIn);
        uint256 _valueIn = sp.amountIn * oracle.getPriceIn18Decimals(sp.tokenIn) / SAFE_MULTIPLIER;
        uint256 _amountOutMinimum = _valueIn * SAFE_MULTIPLIER / oracle.getPriceIn18Decimals(sp.tokenOut)
            / (10 ** (18 - IERC20Metadata(sp.tokenOut).decimals())) * (10000 - sp.slippage) / 10000;

        ISwapRouter.ExactInputSingleParams memory _eisp = ISwapRouter.ExactInputSingleParams({
            tokenIn: sp.tokenIn,
            tokenOut: sp.tokenOut,
            fee: fees[sp.tokenIn][sp.tokenOut],
            recipient: address(this),
            deadline: sp.deadline,
            amountIn: sp.amountIn,
            amountOutMinimum: _amountOutMinimum,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(_eisp);
        uint256 _amountOut = IERC20(sp.tokenOut).balanceOf(address(this));

        IERC20(sp.tokenOut).safeTransfer(msg.sender, _amountOut);

        return _amountOut;
    }
    /**
    * @notice Swap as little tokenIn for exact amount of tokenOut
    * @param sp ISwap.SwapParams
    * @return amountIn Amount of tokens in swapepd; in token decimals
  */
    function swapTokensForExactTokens(ISwap.SwapParams memory sp) external returns (uint256) {
        IERC20(sp.tokenIn).safeTransferFrom(
      msg.sender,
      address(this),
      sp.amountIn
    );

    IERC20(sp.tokenIn).approve(address(router), sp.amountIn);
      ISwapRouter.ExactOutputSingleParams memory _eosp =
      ISwapRouter.ExactOutputSingleParams({
        tokenIn: sp.tokenIn,
        tokenOut: sp.tokenOut,
        fee: fees[sp.tokenIn][sp.tokenOut],
        recipient: address(this),
        deadline: sp.deadline,
        amountOut: sp.amountOut,
        amountInMaximum: sp.amountIn,
        sqrtPriceLimitX96: 0
      });

    uint256 _amountIn = router.exactOutputSingle(_eosp);


    // Return sender back any unused tokenIn
    IERC20(sp.tokenIn).safeTransfer(
      msg.sender,
      IERC20(sp.tokenIn).balanceOf(address(this))
    );

    IERC20(sp.tokenOut).safeTransfer(
      msg.sender,
      IERC20(sp.tokenOut).balanceOf(address(this))
    );

    return _amountIn;

    }
}
