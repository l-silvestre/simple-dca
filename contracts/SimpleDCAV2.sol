// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import './IWETH.sol';

/// @title Dollar cost average implementation
/// @dev All function calls are currently implemented without side effect
contract SimpleDCAV2 is Ownable {
  // declare public immutable swap router router
  ISwapRouter public immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  // make token addresses public so they can be verified by anyone
  mapping (string => address) public tokenAddresses;
  struct TokenAddr {
    string symbol;
    address addr;
  }
  uint24 public constant POOL_FEE = 3000;
  uint256 public constant MIN_INVESTMENT_TIME = 5 days;
  uint256 public constant MAX_INVESTMENT_TIME = 365 days;
  uint256 public constant MAX_INVESTMENTS = 5;


  struct Investment{
    string symbol;
    uint256 avgBuyAmount;
    uint256 expiryTimestamp;
  }
  // investment logic state
  // map each address to a investment struct array
  mapping (address => Investment[]) internal investments;

  // mapping (address => string[]) private investedTokens;

  // map investment tokens to their index for each address
  mapping (address => mapping (string => uint256)) private indexes;

  address[] internal accounts;
  mapping (address => uint) internal accountIndexes;

  event InvestmentStarted(address owner, Investment investment);
  event InvestmentStopped(address owner, Investment investment);

  constructor(TokenAddr[] memory _tokenAddresses) {
    // initialize 
    for (uint256 i = 0; i < _tokenAddresses.length; i++) {
      TokenAddr memory temp = _tokenAddresses[i];
      tokenAddresses[temp.symbol] = temp.addr;
    }
  }

  modifier isAllowedToken(string memory _tokenSymbol) {
    require(tokenAddresses[_tokenSymbol] != address(0), 'This Contract does not support provided token symbol'); 
    // requires token addresses mapping to have an address for passed tokenSymbol
    _;
  }

  modifier hasEnoughBalance(string memory _tokenSymbol, uint256 _amount) {
    require(getUserTokenBalance(_tokenSymbol) > _amount, 'Not enough funds');
    _;
  }

  modifier hasEnoughAllowance(string memory _tokenSymbol, uint256 _amount) {
    require(getAllowance(_tokenSymbol) >= _amount, 'Must approve correct amount of USDC tokens before swap');
    _;
  }

  function getUserTokenBalance(string memory _tokenSymbol) public view isAllowedToken(_tokenSymbol) returns (uint256){
    return IERC20(tokenAddresses[_tokenSymbol]).balanceOf(msg.sender);
  }
   
  function getAllowance(string memory _tokenSymbol) public view isAllowedToken(_tokenSymbol) returns (uint256) {
    return IERC20(tokenAddresses[_tokenSymbol]).allowance(msg.sender, address(this));
  }

  /// @notice swapExactInputSingle swaps a fixed amount of USDC for a maximum possible amount of @param _tokenOutSymbol
  /// using a 0.3% pool by calling `exactInputSingle` in the swap router.
  /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its USDC for this function to succeed.
  /// @param _amountIn The exact amount of USDC that will be swapped for @param _tokenOutSymbol.
  /// @param _tokenOutSymbol The symbol of the token to be swapped with
  /// @param _receiver Address of the swap recipient
  /// @return amountOut The amount received of desired token.
  function swapExactInputSingle(uint256 _amountIn, string memory _tokenOutSymbol, address _receiver)
    internal
    isAllowedToken(_tokenOutSymbol)
    hasEnoughBalance('USDC', _amountIn)
    hasEnoughAllowance('USDC', _amountIn)
    returns (uint256 amountOut)
  {
    require(accountIndexes[_receiver] != 0, 'Recipient addres is an account in the contract');
    address usdc = tokenAddresses['USDC'];
    address tokenOut = tokenAddresses[_tokenOutSymbol];
    // Transfer the specified amount of USDC to this contract.
    TransferHelper.safeTransferFrom(usdc,_receiver, address(this), _amountIn);
    // Approve the router to spend USDC. (approve the total amount)
    TransferHelper.safeApprove(usdc, address(swapRouter), _amountIn);
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: usdc,
        tokenOut: tokenOut,
        fee: POOL_FEE,
        recipient: _receiver,
        deadline: block.timestamp,
        amountIn: _amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    // The call to `exactInputSingle` executes the swap.
    amountOut = swapRouter.exactInputSingle(params);
  }

  function swapWETHtoUSDC(uint256 _amount)
    external
    payable
    hasEnoughBalance('WETH', _amount)
    hasEnoughAllowance('WETH', _amount)
    returns (uint256 amountOut)
  {
    address weth = tokenAddresses['WETH'];
    address usdc = tokenAddresses['USDC'];

    // weth must be approved before
    TransferHelper.safeTransferFrom(weth , msg.sender, address(this), _amount);
    // aprove weth spending by the router
    TransferHelper.safeApprove(weth, address(swapRouter), _amount);
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: weth,
        tokenOut: usdc,
        fee: POOL_FEE,
        recipient: msg.sender,
        deadline: block.timestamp,
        amountIn: _amount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    // The call to `exactInputSingle` executes the swap.
    amountOut = swapRouter.exactInputSingle(params);
  }

  function wrapEth() public payable returns (bool) {
    require(msg.value > 0.05 ether, 'Must pass at least 0.1 ETH in msg.value');

    address weth = tokenAddresses['WETH'];
    IWETH wethToken = IWETH(weth);

    wethToken.deposit{value: msg.value}();
    wethToken.transfer(msg.sender, msg.value);

    return true;
  }

  function approveRouter(uint256 _amountIn) public returns (bool) {
    address usdc = tokenAddresses['USDC'];
    TransferHelper.safeApprove(usdc, address(swapRouter), _amountIn);

    return true;
  }

  function startInvestment(uint256 _amount, string memory _buyTokenSymbol, uint256 _duration, address account)
    internal
    isAllowedToken(_buyTokenSymbol)
    hasEnoughBalance('USDC', _amount)
    hasEnoughAllowance('USDC', _amount)
    returns (uint256)
  {
    _duration = 10 minutes; // testing value
    // require(_duration >= MIN_INVESTMENT_TIME && _duration <= MAX_INVESTMENT_TIME, 'Duration must be between 5 and 365 days');
    require(_duration >= 10 minutes && _duration <= 20 minutes, 'Duration must be between 10 and 20 minutes');
    require(_amount > 0, 'Amount must be greater than 0');
    require(_checkMaxInvestments(account), 'Can only have 5 activate investments at the same time');
    require(!_checkInvestmentExists(account, _buyTokenSymbol), 'Only one investment per token is permitted');
  
    // calculate expiryTimestamp
    uint256 expiryTimestamp = block.timestamp + _duration;
    uint256 nIntervals = _duration / 60 / 2; // 2 minutes iteration
    uint256 averageBuyAmount = _amount / nIntervals;

    Investment memory investment = Investment(_buyTokenSymbol, averageBuyAmount, expiryTimestamp);
    investments[account].push(investment);
    // investedTokens[account].push(_buyTokenSymbol);
    // store index of current investment symbol for that user
    indexes[account][investment.symbol] = investments[account].length;
    if (accountIndexes[account] == 0) {
      accounts.push(account);
      accountIndexes[account] = accounts.length;
    } // else user account is already registered and indexed
    
    emit InvestmentStarted(account, investment);

    return accounts.length;
  }

  function stopInvestment(address _user, string memory _buyTokenSymbol)
    internal
    isAllowedToken(_buyTokenSymbol)
    returns (bool)
  {
    require(_checkInvestmentExists(_user, _buyTokenSymbol), 'Investment not found');
    uint256 idx = indexes[_user][_buyTokenSymbol] - 1;

    // store element to delete for event emit
    Investment memory toDelete = investments[_user][idx];
    // copy last element to position of element to remove
    investments[_user][idx] = investments[_user][investments[_user].length - 1];
    // remove last element
    investments[_user].pop();
    // update indexes mapping
    // delete removed elemnt index
    delete indexes[_user][_buyTokenSymbol];
    // replace previous last element with new index
    string memory symbol = investments[_user][idx].symbol;
    indexes[_user][symbol] = idx;

    if (investments[_user].length == 0) {
      uint accountIdx = accountIndexes[_user] - 1;
      accounts[accountIdx] = accounts[accounts.length - 1];
      accounts.pop();

      delete accountIndexes[_user];
      accountIndexes[accounts[accountIdx]] = accountIdx;
    }

    emit InvestmentStarted(msg.sender, toDelete);
    return true;
  }

  function _checkInvestmentExists(address _user, string memory _buyTokenSymbol) internal view returns (bool) {
    return indexes[_user][_buyTokenSymbol] != 0;
  }

  function _checkMaxInvestments(address _user) internal view returns (bool) {
    // return investments[_user].length < (maxInvestments - 1) && investedTokens[_user].length < (maxInvestments - 1);
    return investments[_user].length < (MAX_INVESTMENTS - 1);
  }

  function _compareStrings(string memory _a, string memory _b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
  }
}