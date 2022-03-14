// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { SafeMath } from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';


//#########################################################################################################################################
library Account {
  enum Status {
    Normal,
    Liquid,
    Vapor
  }
  struct Info {
    address owner; // The address that owns the account
    uint number; // A nonce that allows a single address to control many accounts
  }
  struct accStorage {
    mapping(uint => Types.Par) balances; // Mapping from marketId to principal
    Status status;
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

  enum AccountLayout {
    OnePrimary,
    TwoPrimary,
    PrimaryAndSecondary
  }

  enum MarketLayout {
    ZeroMarkets,
    OneMarket,
    TwoMarkets
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

  struct DepositArgs {
    Types.AssetAmount amount;
    Account.Info account;
    uint market;
    address from;
  }

  struct WithdrawArgs {
    Types.AssetAmount amount;
    Account.Info account;
    uint market;
    address to;
  }

  struct TransferArgs {
    Types.AssetAmount amount;
    Account.Info accountOne;
    Account.Info accountTwo;
    uint market;
  }

  struct BuyArgs {
    Types.AssetAmount amount;
    Account.Info account;
    uint makerMarket;
    uint takerMarket;
    address exchangeWrapper;
    bytes orderData;
  }

  struct SellArgs {
    Types.AssetAmount amount;
    Account.Info account;
    uint takerMarket;
    uint makerMarket;
    address exchangeWrapper;
    bytes orderData;
  }

  struct TradeArgs {
    Types.AssetAmount amount;
    Account.Info takerAccount;
    Account.Info makerAccount;
    uint inputMarket;
    uint outputMarket;
    address autoTrader;
    bytes tradeData;
  }

  struct LiquidateArgs {
    Types.AssetAmount amount;
    Account.Info solidAccount;
    Account.Info liquidAccount;
    uint owedMarket;
    uint heldMarket;
  }

  struct VaporizeArgs {
    Types.AssetAmount amount;
    Account.Info solidAccount;
    Account.Info vaporAccount;
    uint owedMarket;
    uint heldMarket;
  }

  struct CallArgs {
    Account.Info account;
    address callee;
    bytes data;
  }
}
//#########################################################################################################################################
library Decimal {
  struct D256 {
    uint value;
  }
}
//#########################################################################################################################################
library Interest {
  struct Rate {
    uint value;
  }

  struct Index {
    uint96 borrow;
    uint96 supply;
    uint32 lastUpdate;
  }
}
//#########################################################################################################################################
library Monetary {
  struct Price {
    uint value;
  }
  struct Value {
    uint value;
  }
}
//#########################################################################################################################################
library Storage {
  // All information necessary for tracking a market
  struct Market {
    // Contract address of the associated ERC20 token
    address token;
    // Total aggregated supply and borrow amount of the entire market
    Types.TotalPar totalPar;
    // Interest index of the market
    Interest.Index index;
    // Contract address of the price oracle for this market
    address priceOracle;
    // Contract address of the interest setter for this market
    address interestSetter;
    // Multiplier on the marginRatio for this market
    Decimal.D256 marginPremium;
    // Multiplier on the liquidationSpread for this market
    Decimal.D256 spreadPremium;
    // Whether additional borrows are allowed for this market
    bool isClosing;
  }

  // The global risk parameters that govern the health and security of the system
  struct RiskParams {
    // Required ratio of over-collateralization
    Decimal.D256 marginRatio;
    // Percentage penalty incurred by liquidated accounts
    Decimal.D256 liquidationSpread;
    // Percentage of the borrower's interest fee that gets passed to the suppliers
    Decimal.D256 earningsRate;
    // The minimum absolute borrow value of an account
    // There must be sufficient incentivize to liquidate undercollateralized accounts
    Monetary.Value minBorrowedValue;
  }

  // The maximum RiskParam values that can be set
  struct RiskLimits {
    uint64 marginRatioMax;
    uint64 liquidationSpreadMax;
    uint64 earningsRateMax;
    uint64 marginPremiumMax;
    uint64 spreadPremiumMax;
    uint128 minBorrowedValueMax;
  }

  // The entire storage state of Solo
  struct State {
    // number of markets
    uint numMarkets;
    // marketId => Market
    mapping(uint => Market) markets;
    // owner => account number => Account
    mapping(address => mapping(uint => Account.accStorage)) accounts;
    // Addresses that can control other users accounts
    mapping(address => mapping(address => bool)) operators;
    // Addresses that can control all users accounts
    mapping(address => bool) globalOperators;
    // mutable risk parameters of the system
    RiskParams riskParams;
    // immutable risk limits of the system
    RiskLimits riskLimits;
  }
}
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

  struct TotalPar {
    uint128 borrow;
    uint128 supply;
  }

  struct Par {
    bool sign; // true if positive
    uint128 value;
  }

  struct Wei {
    bool sign; // true if positive
    uint value;
  }
}
//#########################################################################################################################################
interface ISoloMargin {
  struct OperatorArg {
    address operator;
    bool trusted;
  }

  function ownerSetSpreadPremium(uint marketId, Decimal.D256 calldata spreadPremium)
    external;

  function getIsGlobalOperator(address operator) external view returns (bool);

  function getMarketTokenAddress(uint marketId) external view returns (address);

  function ownerSetInterestSetter(uint marketId, address interestSetter) external;

  function getAccountValues(Account.Info calldata account)
    external
    view
    returns (Monetary.Value memory, Monetary.Value memory);

  function getMarketPriceOracle(uint marketId) external view returns (address);

  function getMarketInterestSetter(uint marketId) external view returns (address);

  function getMarketSpreadPremium(uint marketId)
    external
    view
    returns (Decimal.D256 memory);

  function getNumMarkets() external view returns (uint);

  function ownerWithdrawUnsupportedTokens(address token, address recipient)
    external
    returns (uint);

  function ownerSetMinBorrowedValue(Monetary.Value calldata minBorrowedValue) external;

  function ownerSetLiquidationSpread(Decimal.D256 calldata spread) external;

  function ownerSetEarningsRate(Decimal.D256 calldata earningsRate) external;

  function getIsLocalOperator(address _owner, address operator)
    external
    view
    returns (bool);

  function getAccountPar(Account.Info calldata account, uint marketId)
    external
    view
    returns (Types.Par memory);

  function ownerSetMarginPremium(uint marketId, Decimal.D256 calldata marginPremium)
    external;

  function getMarginRatio() external view returns (Decimal.D256 memory);

  function getMarketCurrentIndex(uint marketId)
    external
    view
    returns (Interest.Index memory);

  function getMarketIsClosing(uint marketId) external view returns (bool);

  function getRiskParams() external view returns (Storage.RiskParams memory);

  function getAccountBalances(Account.Info calldata account)
    external
    view
    returns (
      address[] memory,
      Types.Par[] memory,
      Types.Wei[] memory
    );

  function renounceOwnership() external;

  function getMinBorrowedValue() external view returns (Monetary.Value memory);

  function setOperators(OperatorArg[] calldata args) external;

  function getMarketPrice(uint marketId) external view returns (address);

  function owner() external view returns (address);

  function isOwner() external view returns (bool);

  function ownerWithdrawExcessTokens(uint marketId, address recipient)
    external
    returns (uint);

  function ownerAddMarket(
    address token,
    address priceOracle,
    address interestSetter,
    Decimal.D256 calldata marginPremium,
    Decimal.D256 calldata spreadPremium
  ) external;

  function operate(
    Account.Info[] calldata accounts,
    Actions.ActionArgs[] calldata actions
  ) external;

  function getMarketWithInfo(uint marketId)
    external
    view
    returns (
      Storage.Market memory,
      Interest.Index memory,
      Monetary.Price memory,
      Interest.Rate memory
    );

  function ownerSetMarginRatio(Decimal.D256 calldata ratio) external;

  function getLiquidationSpread() external view returns (Decimal.D256 memory);

  function getAccountWei(Account.Info calldata account, uint marketId)
    external
    view
    returns (Types.Wei memory);

  function getMarketTotalPar(uint marketId)
    external
    view
    returns (Types.TotalPar memory);

  function getLiquidationSpreadForPair(uint heldMarketId, uint owedMarketId)
    external
    view
    returns (Decimal.D256 memory);

  function getNumExcessTokens(uint marketId) external view returns (Types.Wei memory);

  function getMarketCachedIndex(uint marketId)
    external
    view
    returns (Interest.Index memory);

  function getAccountStatus(Account.Info calldata account)
    external
    view
    returns (uint8);

  function getEarningsRate() external view returns (Decimal.D256 memory);

  function ownerSetPriceOracle(uint marketId, address priceOracle) external;

  function getRiskLimits() external view returns (Storage.RiskLimits memory);

  function getMarket(uint marketId) external view returns (Storage.Market memory);

  function ownerSetIsClosing(uint marketId, bool isClosing) external;

  function ownerSetGlobalOperator(address operator, bool approved) external;

  function transferOwnership(address newOwner) external;

  function getAdjustedAccountValues(Account.Info calldata account)
    external
    view
    returns (Monetary.Value memory, Monetary.Value memory);

  function getMarketMarginPremium(uint marketId)
    external
    view
    returns (Decimal.D256 memory);

  function getMarketInterestRate(uint marketId)
    external
    view
    returns (Interest.Rate memory);
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
    address sender,
    Account.Info memory account,
    bytes memory data
  ) public override {
    require(msg.sender == SOLO, "!solo");
    require(sender == address(this), "!this contract");

    MyCustomData memory mcd = abi.decode(data, (MyCustomData));
    uint repayAmount = mcd.repayAmount;

    arb_swap(the_routers[0], the_routers[1], tokens_addresses[0], tokens_addresses[1], quantities[0]);
   
    uint bal = IERC20(mcd.token).balanceOf(address(this));
    require(bal >= repayAmount, "bal < repay");

    // More code here...
    flashUser = sender;
    emit Log("bal", bal);
    emit Log("repay", repayAmount);
    emit Log("bal - repay", bal - repayAmount);
  }
}
