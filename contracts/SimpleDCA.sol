// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWETH9 is IERC20 {
  function deposit() external payable;
  function withdraw(uint amount) external;
}
contract SimpleDCA is Ownable, AccessControl {
  ISwapRouter public immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  IERC20 usdcToken = IERC20(USDC);
  IERC20 wbtcToken = IERC20(WBTC);
  IWETH9 wethToken = IWETH9(WETH9);

  uint256 public buyInterval = 1 days;
  uint256 public minLockDuration = 30 seconds;
  uint256 public maxLockDuration = 365 days;
  // For this example, we will set the pool fee to 0.01%.
  uint24 public constant poolFee = 3000;

  struct LockInformation {
    string tokenSymbol;
    uint256 tokenAmount;
    uint256 stepAmount;
    uint256 expiryTimestamp;
  }

  mapping (address => LockInformation[]) userLockInfo;
  mapping (address => bool) lockedAccounts;

  constructor() {
    // this token address is LINK token deployed on Rinkeby testnet
    // You can use any other ERC20 token smart contract address here
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    // buyInterval = _buyInterval;
    /* 
    minLockDuration = _minLockDuration;
    maxLockDuration = _maxLockDuration;
    */
  }

  modifier IsValidToken(string memory _tokenSymbol, bool _onlyUSDC) {
    if (_onlyUSDC) {
      require(_compareStrings(_tokenSymbol, 'USDC'), "Token Symbol MUST be 'USDC'");
    } else {
      require(
        _compareStrings(_tokenSymbol, 'USDC') ||
        _compareStrings(_tokenSymbol, 'WBTC') ||
        _compareStrings(_tokenSymbol, 'WETH'),
        "Token Symbol MUST be 'USDC' or 'WBTC'"
      );
    }
    _;
  }

  function GetUserTokenBalance(string memory _tokenSymbol) public view IsValidToken(_tokenSymbol, false) returns (uint256){
    if (_compareStrings(_tokenSymbol, 'USDC')) {
      return usdcToken.balanceOf(msg.sender);
    } else if (_compareStrings(_tokenSymbol, 'WBTC')) {
      return wbtcToken.balanceOf(msg.sender);
    } else {
      return wethToken.balanceOf(msg.sender);
    }
  }

  /*  function Approvetokens(uint256 _tokenamount) public returns(bool){
    usdcToken.approve(address(this), _tokenamount);
    return true;
  } */
   
  function GetAllowance(string memory _tokenSymbol) public view IsValidToken(_tokenSymbol, false) returns(uint256){
    if (_compareStrings(_tokenSymbol, 'USDC')) {
      return usdcToken.allowance(msg.sender, address(this));
    } else {
      return wbtcToken.allowance(msg.sender, address(this));
    }
  }

  function Approve(uint256 _amount) public IsValidToken("USDC", true) returns (bool) {
    // uint256 userBalance = GetUserTokenBalance("USDC");
    uint256 userBalance = usdcToken.balanceOf(msg.sender);
    require( userBalance >= _amount, "Wallet does not have enough balance");
    // Approve this contract to spend USDC. (approve the total amount)
    return usdcToken.approve(address(this), _amount);
    // require(GetAllowance("USDC") > 0, "Aproval error");
    //return true;
  }
   
  function LockTokens(uint256 _tokenamount, uint256 _duration, string memory _buyTokenSymbol) IsValidToken(_buyTokenSymbol, true) public returns(bool) {
    // require(_tokenamount >= GetAllowance(), "Please approve tokens before transferring");
    require(GetUserTokenBalance(_buyTokenSymbol) >= _tokenamount, "Wallet does not have enough balance");
    require(_duration >= minLockDuration && _duration <= maxLockDuration, "Tokens can not be locked for less than 7 days or more than 365 days");
    
    // no need for if as modifier enforces only usdc can be passed as _buyTokenSymbol
    // if (_compareStrings(_buyTokenSymbol, 'USDC')) {
    // Transfer the specified amount of USDC to this contract.
    TransferHelper.safeTransferFrom(USDC, msg.sender, address(this), _tokenamount);
    // TransferHelper.safeTransferFrom(USDC, msg.sender, address(this), _tokenamount);
    // Approve the router to spend USDC. (approve the total amount)
    TransferHelper.safeApprove(USDC, address(swapRouter), _tokenamount);
    // }

    uint256 expiryTimestamp = _calculateExpiryTimestamp(_duration, block.timestamp);
    uint256 nIterations = _calculateIterations(_duration);
    LockInformation memory lockInfo = LockInformation(_buyTokenSymbol, _tokenamount,  nIterations, expiryTimestamp);

    userLockInfo[msg.sender].push(lockInfo);
    lockedAccounts[msg.sender] = true;
    return true;
  }

  function UnlockTokens() public {
    require(lockedAccounts[msg.sender]);
    LockInformation[] storage userLocks = userLockInfo[msg.sender];

    for (uint i = 0; i< userLocks.length; i++) {
      LockInformation storage info = userLocks[i];
      if (_compareStrings(info.tokenSymbol, 'USDC') && info.tokenAmount > 0) {
        // Transfer the specified amount of USDC from this contract back to the user.
        TransferHelper.safeTransferFrom(USDC, address(this), msg.sender, info.tokenAmount);
        // revert contract approval by setting amount to 0 (hacky way !?)
        TransferHelper.safeApprove(USDC, address(swapRouter), 0);
      } else if (_compareStrings(info.tokenSymbol, 'WBTC') && info.tokenAmount > 0) {
        // Transfer the specified amount of WBTC from this contract back to the user.
        TransferHelper.safeTransferFrom(WBTC, address(this), msg.sender, info.tokenAmount);
        // revert contract approval by setting amount to 0 (hacky way !?)
        TransferHelper.safeApprove(WBTC, address(swapRouter), 0);
      }
    }
    
    delete lockedAccounts[msg.sender];
    delete userLockInfo[msg.sender];
  }
   
  function GetContractTokenBalance(string memory _tokenSymbol) public view onlyOwner IsValidToken(_tokenSymbol, false) returns(uint256){
    if (_compareStrings(_tokenSymbol, 'USDC')) {
      return usdcToken.balanceOf(address(this));
    } else if (_compareStrings(_tokenSymbol, 'WBTC')) {
      return wbtcToken.balanceOf(address(this));
    } else {
      return wethToken.balanceOf(address(this));
    }
  }

  /// @notice swapExactInputSingle swaps a fixed amount of DAI for a maximum possible amount of WETH9
  /// using the DAI/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
  /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
  /// @param amountIn The exact amount of DAI that will be swapped for WETH9.
  /// @return amountOut The amount of WETH9 received.
  function swapExactInputSingle(uint256 amountIn) external returns (uint256 amountOut) {
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: USDC,
        tokenOut: WBTC,
        fee: poolFee,
        recipient: msg.sender,
        deadline: block.timestamp,
        amountIn: amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    // The call to `exactInputSingle` executes the swap.
    amountOut = swapRouter.exactInputSingle(params);
  }

  function swapForUSDC() external payable returns (uint256 amountOut) {
    require(msg.value > 0.1 ether, "Msg.value must be greater than 1");

    wethToken.deposit{value: msg.value}();
    require(wethToken.balanceOf(address(this)) == msg.value, "Contract does not have the correct weth amount");
    // 
    TransferHelper.safeApprove(WETH9, address(swapRouter), msg.value);
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: WETH9,
        tokenOut: USDC,
        fee: poolFee,
        recipient: msg.sender,
        deadline: block.timestamp + 30 seconds,
        amountIn: msg.value,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    // The call to `exactInputSingle` executes the swap.
    amountOut = swapRouter.exactInputSingle(params);
  }

  function swapForWETH() public payable returns (bool) {
    require(msg.value > 0.1 ether, "Must pass at least 0.1 ETH in msg.value");

    wethToken.deposit{value: msg.value}();
    wethToken.transfer(msg.sender, msg.value);
    return true;
  }

  // --
  // internal pure functions to implement repetitive logic
  // --

  function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }

  function _calculateExpiryTimestamp(uint256 _durationTimestamp, uint256 currentTimestamp) internal pure returns (uint256) {
    uint256 expiry = currentTimestamp + _durationTimestamp;
    uint256 interval = 1 days;
    uint256 offset = expiry % interval;
    uint256 rounded = expiry - offset;

    if (offset > (interval / 2)) {
      return rounded + interval;
    } else {
      return rounded;
    }
  }

  function _calculateIterations(uint256 _durationTimestamp) internal pure returns (uint256) {
    uint256 roundedDays = _durationTimestamp % 1 days;
    return roundedDays / 1 days;
  }
}
