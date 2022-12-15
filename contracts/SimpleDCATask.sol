// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
pragma abicoder v2;

import './SimpleDCAV2.sol';
import './gelato/OpsTaskCreator.sol';

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract SimpleDCATask is OpsTaskCreator, SimpleDCAV2 {
  uint256 public immutable interval;

  /// @notice map gelato taskId to index in investments array for each registered address 
  /// @dev Explain to a developer any extra details
  mapping (address => mapping (bytes32 => uint256)) private accountTaskToInvestmentIdx;

  /// @notice map index in investments array to gelato taskId for each registered address
  /// @dev Explain to a developer any extra details
  mapping (address => mapping (uint256 => bytes32)) private accountInvestmentIdxToTask;

  // events
  event TaskCreatedEvent(bytes32 taskId);
  event TaskCanceledEvent(bytes32 taskId);
  event TaskFinishedEvent(bytes32 taskId);
  event Received(uint);
  event Deposited(uint);
  event Withdrawn(uint);

  receive() external payable {
    emit Received(msg.value);
  }

  constructor(address _ops, address _fundsOwner, TokenAddr[] memory _tokens)
    OpsTaskCreator(_ops, _fundsOwner)
    SimpleDCAV2(_tokens)
  {
    interval = 2 minutes; // testing value
  }

  function deposit() external payable onlyOwner() {
    _depositFunds(msg.value, ETH);
    emit Deposited(msg.value);
  }

  function withdraw() external payable onlyOwner() {
    payable(msg.sender).transfer(address(this).balance);
    emit Withdrawn(msg.value);
  }

  function getBalance() external view returns (uint) {
    return address(this).balance;
  }

  /// @notice Explain to an end user what this does
  /// @dev Explain to a developer any extra details
  /// @param _amount a parameter just like in doxygen (must be followed by parameter name)
  /// @param _buyTokenSymbol string representing the symbol of the token to invest in
  /// @param _duration timestamp
  /// @return (bytes32) taskId
  function createTask(uint256 _amount, string memory _buyTokenSymbol, uint256 _duration)
    external
    payable
    returns (bytes32)
  {
    uint256 accountInvestmentIdx = startInvestment(_amount, _buyTokenSymbol, _duration, msg.sender);

    bytes memory execData = abi.encodeCall(this.invest, (msg.sender, accountInvestmentIdx));
    /* bytes memory execData = abi.encodeCall(this.invest, msg.sender, ); */

    ModuleData memory moduleData = ModuleData({
      modules: new Module[](3),
      args: new bytes[](3)
    });
    moduleData.modules[0] = Module.RESOLVER;
    moduleData.modules[1] = Module.TIME;
    moduleData.modules[2] = Module.PROXY;

    moduleData.args[0] = _resolverModuleArg(
      address(this),
      abi.encodeCall(this.checker, (msg.sender, accountInvestmentIdx))
    );
    moduleData.args[1] = _timeModuleArg(block.timestamp, interval);
    moduleData.args[2] = _proxyModuleArg();

    bytes32 id = _createTask(
      address(this),
      execData,
      moduleData,
      ETH
    );

    accountTaskToInvestmentIdx[msg.sender][id] = accountInvestmentIdx;
    accountInvestmentIdxToTask[msg.sender][accountInvestmentIdx] = id;
    emit TaskCreatedEvent(id);
    return id;
  }

  /*
  function cancelTask(uint256 _accountInvestmentIdx) external returns(bool) {
    return cancelTaskInternal(msg.sender, _accountInvestmentIdx);
  } */

  /// @notice Explain to an end user what this does
  /// @dev Explain to a developer any extra details
  /// @param _account a parameter just like in doxygen (must be followed by parameter name)
  /// @param _accountInvestmenIdx a parameter just like in doxygen (must be followed by parameter name)
  /// @return (bool)
  function cancelTaskInternal(address _account, uint256 _accountInvestmenIdx)
    external
    returns (bool)
  {
    Investment memory temp = investments[msg.sender][_accountInvestmenIdx];

    bool hasCancelled = stopInvestment(msg.sender, temp.symbol);
    if (hasCancelled) {
      bytes32 taskId = accountInvestmentIdxToTask[_account][_accountInvestmenIdx];
      _cancelTask(taskId);
      emit TaskFinishedEvent(taskId);
      return true;
    } else {
      return false;
    }
  }

   /// @notice Explain to an end user what this does
  /// @dev Explain to a developer any extra details
  /// @param _account a parameter just like in doxygen (must be followed by parameter name)
  /// @param _accountInvestmenIdx a parameter just like in doxygen (must be followed by parameter name)
  function checker(address _account, uint256 _accountInvestmenIdx) external view returns (bool canExec, bytes memory execPayload) {
    Investment memory temp = investments[msg.sender][_accountInvestmenIdx];
    canExec = true;
    if (block.timestamp > temp.expiryTimestamp) {
      execPayload = abi.encodeCall(this.cancelTaskInternal, (_account, _accountInvestmenIdx));
    } else {
      execPayload = abi.encodeCall(this.invest, (_account, _accountInvestmenIdx));
    }
  }

  function invest(address _account, uint256 _accountInvestmentIdx) external onlyDedicatedMsgSender returns (bool) {
    Investment memory temp = investments[_account][_accountInvestmentIdx];
    if (block.timestamp < temp.expiryTimestamp) {
      // swap tokens for this user
      swapExactInputSingle(temp.avgBuyAmount, temp.symbol, _account);
    }

    (uint256 fee, address feeToken) = _getFeeDetails();

    _transfer(fee, feeToken);

    return true;
  }

  function getOwnInvestments() external view returns (Investment[] memory) {
    require(accountIndexes[msg.sender] != 0, 'Sender Does not have active investments');
    return investments[msg.sender];
  }
}