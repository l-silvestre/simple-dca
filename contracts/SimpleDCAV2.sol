// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SimpleDCAV2 {
  // declare public immutable swap router router
  ISwapRouter public immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  // make token addresses public so they can be verified by anyone
  mapping (string => address) public tokenAddresses;
  struct TokenAddr {
    string symbol;
    address addr;
  }
  uint24 public constant poolFee = 3000;
  uint256 public constant minInvestmentTime = 5 days;
  uint256 public constant maxInvestmentTime = 365 days;
  uint256 public constant maxInvestments = 5;


  struct Investment{
    string symbol;
    uint256 avgBuyAmount;
    uint256 expiryTimestamp;
  }
  // investment logic state
  // map each address to a investment struct array
  mapping (address => Investment[]) private investments;
  // mapping (address => string[]) private investedTokens;
  // map investment tokens to their index for each for each address
  mapping (address => mapping (string => uint256)) indexes;
  address[] accounts;
  mapping (address => uint) accountIndexes;

  constructor(TokenAddr[] memory _tokenAddresses) {
    // initialize 
    for (uint256 i = 0; i < _tokenAddresses.length; i++) {
      TokenAddr memory temp = _tokenAddresses[i];
      tokenAddresses[temp.symbol] = temp.addr;
    }
  }

  modifier isAllowedToken(string memory _tokenSymbol) {
    require(tokenAddresses[_tokenSymbol] != address(0), "This Contract does not support provided token symbol"); // requires token addresses mapping to have an address for passed tokenSymbol
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
  /// @return amountOut The amount received of desired token.
  function swapExactInputSingle(uint256 _amountIn, string memory _tokenOutSymbol)
    external
    isAllowedToken(_tokenOutSymbol)
    hasEnoughBalance('USDC', _amountIn)
    hasEnoughAllowance('USDC', _amountIn)
    returns (uint256 amountOut)
  {
    address USDC = tokenAddresses['USDC'];
    address tokenOut = tokenAddresses[_tokenOutSymbol];
    // Transfer the specified amount of USDC to this contract.
    // TransferHelper.safeTransferFrom(USDC, msg.sender, address(this), _tokenamount);
    // Approve the router to spend USDC. (approve the total amount)
    // TransferHelper.safeApprove(USDC, address(swapRouter), _amountIn);
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: USDC,
        tokenOut: tokenOut,
        fee: poolFee,
        recipient: msg.sender,
        deadline: block.timestamp,
        amountIn: _amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    // The call to `exactInputSingle` executes the swap.
    amountOut = swapRouter.exactInputSingle(params);
  }

  function approveRouter(uint256 _amountIn) public returns (bool) {
    address USDC = tokenAddresses['USDC'];
    TransferHelper.safeApprove(USDC, address(swapRouter), _amountIn);

    return true;
  }

  function startInvestment(uint256 _amount, string memory _buyTokenSymbol, uint256 _duration)
    public
    isAllowedToken(_buyTokenSymbol)
    hasEnoughBalance('USDC', _amount)
    hasEnoughAllowance('USDC', _amount)
    returns (bool)
  {
    require(_duration >= minInvestmentTime && _duration <= maxInvestmentTime, "Duration must be between 5 and 365 days");
    require(_amount > 0);
    require(_checkMaxInvestments(msg.sender), "Can only have 5 activate investments at the same time");
    require(!_checkInvestmentExists(msg.sender, _buyTokenSymbol), 'Only one investment per token is permitted');
  
    // calculate expiryTimestamp
    uint256 expiryTimestamp = block.timestamp + _duration;
    uint256 nDays = _duration / 60 / 60 / 24;
    uint256 averageBuyAmount = _amount / nDays;

    Investment memory investment = Investment(_buyTokenSymbol, averageBuyAmount, expiryTimestamp);
    investments[msg.sender].push(investment);
    // investedTokens[msg.sender].push(_buyTokenSymbol);
    // store index of current investment symbol for that user
    indexes[msg.sender][investment.symbol] = investments[msg.sender].length;
    if (accountIndexes[msg.sender] == 0) {
      accounts.push(msg.sender);
      accountIndexes[msg.sender] = accounts.length;
    } // else user account is already registered and indexed
    
    // create gelato task

    return true;
  }

  function stopInvestmentSelf(string memory _buyTokenSymbol) public isAllowedToken(_buyTokenSymbol) returns (bool) {
    return stopInvestment(msg.sender, _buyTokenSymbol);
  }

  function stopInvestment(address _user, string memory _buyTokenSymbol)
    public
    isAllowedToken(_buyTokenSymbol)
    returns (bool)
  {
    require(_checkInvestmentExists(_user, _buyTokenSymbol), "Investment not found");
    uint256 idx = indexes[_user][_buyTokenSymbol] - 1;
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

    // cancelTask ??
    return true;
  }

  /* function investAll() public returns (bool) {
    require(accounts.length > 0, "No Accounts with investments");
    for (uint256 i = 0; i < accounts.length; i++) {
      uint256 idx = indexes[accounts[i]];
      
      for (uint256 f = 0; f < maxInvestments; f++) {

      }
    }
  } */

  /* function invest(address _user) public returns (bool) {
    indexes[_user]
  } */

  function _checkInvestmentExists(address _user, string memory _buyTokenSymbol) internal view returns (bool) {
    return indexes[_user][_buyTokenSymbol] != 0;
  }

  function _checkMaxInvestments(address _user) internal view returns (bool) {
    // return investments[_user].length < (maxInvestments - 1) && investedTokens[_user].length < (maxInvestments - 1);
    return investments[_user].length < (maxInvestments - 1);
  }

  function _compareStrings(string memory _a, string memory _b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
  }
}