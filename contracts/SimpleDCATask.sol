// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
pragma abicoder v2;

import './SimpleDCAV2.sol';
import './gelato/OpsTaskCreator.sol';

contract SimpleDCATask is OpsTaskCreator, SimpleDCAV2 {
  uint256 public immutable interval;

  mapping (address => mapping (bytes32 => uint256)) private accountTaskToInvestmentIdx;
  mapping (address => mapping (uint256 => bytes32)) private accountInvestmentIdxToTask;
  event CounterTaskCreated(bytes32 taskId);

  struct InvestmentTask {
    Investment investment;
    bytes32 taskId;
  }

  event Received(address, uint);
  function deposit() external payable onlyOwner() {
    emit Received(msg.sender, msg.value);
  }

  constructor(address _ops, address _fundsOwner, TokenAddr[] memory _tokens)
    OpsTaskCreator(_ops, _fundsOwner)
    SimpleDCAV2(_tokens)
  {
    interval = 2 minutes;
  }

  function createTask(uint256 _amount, string memory _buyTokenSymbol, uint256 _duration)
    external
    returns (bool)
  {
    uint256 accountInvestmentIdx = startInvestment(_amount, _buyTokenSymbol, _duration, msg.sender);

    bytes memory execData = abi.encodeCall(this.invest, (msg.sender, accountInvestmentIdx));
    /* bytes memory execData = abi.encodeCall(this.invest, msg.sender, ); */

    ModuleData memory moduleData = ModuleData({
      modules: new Module[](2),
      args: new bytes[](2)
    });
    moduleData.modules[0] = Module.RESOLVER;
    moduleData.modules[1] = Module.PROXY;

    moduleData.args[0] = _resolverModuleArg(
      address(this),
      abi.encodeCall(this.checker, (msg.sender, accountInvestmentIdx))
    );
    moduleData.args[1] = _proxyModuleArg();

    bytes32 id = _createTask(
      address(this),
      execData,
      moduleData,
      address(0)
    );

    accountTaskToInvestmentIdx[msg.sender][id] = accountInvestmentIdx;
    accountInvestmentIdxToTask[msg.sender][accountInvestmentIdx] = id;
    emit CounterTaskCreated(id);
    return true;
  }

  function cancelTask(uint256 _accountInvestmentIdx) external returns(bool) {
    return cancelTaskInternal(msg.sender, _accountInvestmentIdx);
  }

  function cancelTaskInternal(address _account, uint256 _accountInvestmenIdx)
    private
    returns (bool)
  {
    Investment memory temp = investments[msg.sender][_accountInvestmenIdx];

    bool hasCancelled = stopInvestment(msg.sender, temp.symbol);
    if (hasCancelled) {
      bytes32 taskId = accountInvestmentIdxToTask[_account][_accountInvestmenIdx];
      _cancelTask(taskId);
      return true;
    } else {
      return false;
    }
  }

  function checker(address _account, uint256 _accountInvestmenIdx) external returns (bool canExec, bytes memory execPayload) {
    Investment memory temp = investments[msg.sender][_accountInvestmenIdx];
    canExec = block.timestamp < temp.expiryTimestamp;
    cancelTaskInternal(_account, _accountInvestmenIdx);
    execPayload =abi.encodeCall(this.invest, (_account, _accountInvestmenIdx));
  }
}