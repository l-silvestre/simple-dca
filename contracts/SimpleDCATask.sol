// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
pragma abicoder v2;

import './SimpleDCAV2.sol';
import './gelato/OpsTaskCreator.sol';

contract SimpleDCATask is OpsTaskCreator, SimpleDCAV2 {
  uint256 public lastExecuted;
  bytes32 public taskId;
  bytes32[] public taskIds;
  uint256 public immutable interval;

  event CounterTaskCreated(bytes32 taskId);

  receive() external payable {}

  constructor(address _ops, address _fundsOwner, TokenAddr[] memory _tokens)
    OpsTaskCreator(_ops, _fundsOwner)
    SimpleDCAV2(_tokens)
  {
    interval = 1 minutes;
  }

  function createTask() external {
    require(taskId == bytes32(''), 'Already started task');

    bytes memory execData = abi.encodeCall(this.investAll, ());

    ModuleData memory moduleData = ModuleData({
      modules: new Module[](2),
      args: new bytes[](2)
    });
    moduleData.modules[0] = Module.TIME;
    moduleData.modules[1] = Module.PROXY;

    moduleData.args[0] = _timeModuleArg(block.timestamp, interval);
    moduleData.args[1] = _proxyModuleArg();

    bytes32 id = _createTask(
      address(this),
      execData,
      moduleData,
      address(0)
    );

    taskId = id;
    emit CounterTaskCreated(id);
  }

  /* function createTaskSplitUsers() external {
    require(taskId == bytes32(''), 'Already started task');

    bytes memory execData = abi.encodeCall(this.investAll, ());

    ModuleData memory moduleData = ModuleData({
      modules: new Module[](2),
      args: new bytes[](2)
    });
    moduleData.modules[0] = Module.TIME;
    moduleData.modules[1] = Module.PROXY;

    moduleData.args[0] = _timeModuleArg(block.timestamp, interval);
    moduleData.args[1] = _proxyModuleArg();

    for (uint256 i = 0; i < accounts.length; i++) {
      bytes32 id = _createTask(
        address(this),
        execData,
        moduleData,
        address(0)
      );

      taskIds.push(id);
      emit CounterTaskCreated(id);
    }
  } */
}