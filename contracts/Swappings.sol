// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { SafeMath } from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';


//#########################################################################################################################################
library Account {
  struct Info {
    address owner; // The address that owns the account
    uint number; // A nonce that allows a single address to control many accounts
  }
}
//#########################################################################################################################################
library Actions {
  enum ActionType {
    Deposit, // supply tokens
    Withdraw, // borrow tokens
    Transfer, // transfer balance between accounts
    Buy, // buy an amount of some token (publicly)
    Sell, // sell an amount of some token (publicly)
    Trade, // trade tokens against another account
    Liquidate, // liquidate an undercollateralized or expiring account
    Vaporize, // use excess tokens to zero-out a completely negative account
    Call // send arbitrary data to an address
  }

  struct ActionArgs {
    ActionType actionType;
    uint accountId;
    Types.AssetAmount amount;
    uint primaryMarketId;
    uint secondaryMarketId;
    address otherAddress;
    uint otherAccountId;
    bytes data;
  }

  
}
//#########################################################################################################################################
//library Decimal {}
//#########################################################################################################################################
//library Interest {}
//#########################################################################################################################################
//library Monetary {}
//#########################################################################################################################################
//library Storage {}
//#########################################################################################################################################
library Types {
  enum AssetDenomination {
    Wei, // the amount is denominated in wei
    Par // the amount is denominated in par
  }

  enum AssetReference {
    Delta, // the amount is given as a delta from the current value
    Target // the amount is given as an exact number to end up at
  }

  struct AssetAmount {
    bool sign; // true if positive
    AssetDenomination denomination;
    AssetReference ref;
    uint value;
  }

}
//#########################################################################################################################################
interface ISoloMargin {
  function getMarketTokenAddress(uint marketId) external view returns (address);

  function getNumMarkets() external view returns (uint);

  function operate(
    Account.Info[] calldata accounts,
    Actions.ActionArgs[] calldata actions
  ) external;

  
}
//#########################################################################################################################################
contract DydxFlashloanBase {
  using SafeMath for uint;

  // -- Internal Helper functions -- //

  function _getMarketIdFromTokenAddress(address _solo, address token)
    internal
    view
    returns (uint)
  {
    ISoloMargin solo = ISoloMargin(_solo);

    uint numMarkets = solo.getNumMarkets();

    address curToken;
    for (uint i = 0; i < numMarkets; i++) {
      curToken = solo.getMarketTokenAddress(i);

      if (curToken == token) {
        return i;
      }
    }

    revert("No marketId found for provided token");
  }

  function _getRepaymentAmountInternal(uint amount) internal pure returns (uint) {
    // Needs to be overcollateralize
    // Needs to provide +2 wei to be safe
    return amount.add(2);
  }

  function _getAccountInfo() internal view returns (Account.Info memory) {
    return Account.Info({owner: address(this), number: 1});
  }

  function _getWithdrawAction(uint marketId, uint amount)
    internal
    view
    returns (Actions.ActionArgs memory)
  {
    return
      Actions.ActionArgs({
        actionType: Actions.ActionType.Withdraw,
        accountId: 0,
        amount: Types.AssetAmount({
          sign: false,
          denomination: Types.AssetDenomination.Wei,
          ref: Types.AssetReference.Delta,
          value: amount
        }),
        primaryMarketId: marketId,
        secondaryMarketId: 0,
        otherAddress: address(this),
        otherAccountId: 0,
        data: ""
      });
  }

  function _getCallAction(bytes memory data)
    internal
    view
    returns (Actions.ActionArgs memory)
  {
    return
      Actions.ActionArgs({
        actionType: Actions.ActionType.Call,
        accountId: 0,
        amount: Types.AssetAmount({
          sign: false,
          denomination: Types.AssetDenomination.Wei,
          ref: Types.AssetReference.Delta,
          value: 0
        }),
        primaryMarketId: 0,
        secondaryMarketId: 0,
        otherAddress: address(this),
        otherAccountId: 0,
        data: data
      });
  }

  function _getDepositAction(uint marketId, uint amount)
    internal
    view
    returns (Actions.ActionArgs memory)
  {
    return
      Actions.ActionArgs({
        actionType: Actions.ActionType.Deposit,
        accountId: 0,
        amount: Types.AssetAmount({
          sign: true,
          denomination: Types.AssetDenomination.Wei,
          ref: Types.AssetReference.Delta,
          value: amount
        }),
        primaryMarketId: marketId,
        secondaryMarketId: 0,
        otherAddress: address(this),
        otherAccountId: 0,
        data: ""
      });
  }
}
//#########################################################################################################################################
interface ICallee {
  // ============ Public Functions ============

  /**
   * Allows users to send this contract arbitrary data.
   *
   * @param  sender       The msg.sender to Solo
   * @param  accountInfo  The account from which the data is being sent
   * @param  data         Arbitrary data given by the sender
   */
  function callFunction(
    address sender,
    Account.Info calldata accountInfo,
    bytes calldata data
  ) external;
}
//#########################################################################################################################################
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Swappings is ICallee, DydxFlashloanBase {
  address public owner;  
  address private constant SOLO = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
  uint256[] public quantities;
  address[] public tokens_addresses;
  address[] public the_routers;

  // JUST FOR TESTING - ITS OKAY TO REMOVE ALL OF THESE VARS
  address public flashUser;
  IUniswapV2Router02 public Router;

  event Log(string message, uint val);

  constructor(address _owner) {
      owner = _owner;
  }

  modifier onlyOwner() {
      require(msg.sender == owner, "Not the Owner");
      _;
  }

  struct MyCustomData {
    address token;
    uint repayAmount;
  }

  function swap(address _router, address _tokenIn, address _tokenOut, uint256 _amountIn) public {

    require(_amountIn <= IERC20(_tokenIn).balanceOf(address(this)), "Insufficient balance, please fund this contract!");

    Router = IUniswapV2Router02(_router);

    IERC20(_tokenIn).approve(address(Router), _amountIn);

    address[] memory _path = get_path(_tokenIn, _tokenOut);

    uint _amountOutMin = get_amountsOut(_amountIn, _path, Router);

    Router.swapExactTokensForTokens(_amountIn, _amountOutMin, _path, address(this), block.timestamp + 300); 
   }

  function arb_swap(address _router_a, address _router_b, address _token_a, address _token_b, uint256 _amountIn) public {
    swap(_router_a, _token_a, _token_b, _amountIn);
    swap(_router_b, _token_b, _token_a, get_contract_token_balance(_token_b));
  }

  function get_path(address _tokenIn, address _tokenOut) internal pure returns (address[] memory) {
    address[] memory path;
    path = new address[](2);
    path[0] = _tokenIn;
    path[1] = _tokenOut;
    return path;
  }

  function get_amountsOut(uint256 _amountIn, address[] memory _path, IUniswapV2Router02 _router) internal view returns (uint) {
    uint256[] memory amountsOut = _router.getAmountsOut(_amountIn, _path);
    uint amountOutMin = amountsOut[amountsOut.length - 1];
    return amountOutMin;
  }

  function get_contract_token_balance(address _token) public view returns (uint) {
      return IERC20(_token).balanceOf(address(this));
  }

  function transfer_amount(address _token, uint256 _amount) onlyOwner public returns ( bool ) {
      uint balance = get_contract_token_balance(_token);
      require(balance >= _amount, "The amount exceeds balance");
      bool check = IERC20(_token).transfer(msg.sender, _amount);
      return check;
  }

  function transfer_full_amount(address _token) onlyOwner public returns ( bool ) {
      uint balance = get_contract_token_balance(_token);
      require(balance > 0, "This constract has insufficient balance");   
      bool check = IERC20(_token).transfer(msg.sender, balance);
      return check;
  }

  function get_tokens() public view returns (address[] memory) {
    return tokens_addresses;
  }

  function initiateFlashLoan(address router_a, address router_b, address token_a, address token_b, uint quantity) external onlyOwner {
    ISoloMargin solo = ISoloMargin(SOLO);

    quantities = [quantity];
    tokens_addresses = [token_a, token_b];
    the_routers = [router_a, router_b];
    // Get marketId from token address
    /*
    0	WETH
    1	SAI
    2	USDC
    3	DAI
    */
    uint marketId = _getMarketIdFromTokenAddress(SOLO, token_a);

    // Calculate repay amount (_amount + (2 wei))
    uint repayAmount = _getRepaymentAmountInternal(quantity);
    IERC20(token_a).approve(SOLO, repayAmount);

    /*
    1. Withdraw
    2. Call callFunction()
    3. Deposit back
    */

    Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

    operations[0] = _getWithdrawAction(marketId, quantity);
    operations[1] = _getCallAction(
      abi.encode(MyCustomData({token: token_a, repayAmount: repayAmount}))
    );
    operations[2] = _getDepositAction(marketId, repayAmount);

    Account.Info[] memory accountInfos = new Account.Info[](1);
    accountInfos[0] = _getAccountInfo();

    solo.operate(accountInfos, operations);
  
  }

  function callFunction(
    address,
    Account.Info memory,
    bytes memory data
  ) public override {

    arb_swap(the_routers[0], the_routers[1], tokens_addresses[0], tokens_addresses[1], quantities[0]);
    
  }
}
