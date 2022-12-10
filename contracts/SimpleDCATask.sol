// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
pragma abicoder v2;

import "./SimpleDCAV2.sol";
import "./gelato/OpsTaskCreator.sol";

contract SimpleDCATask is OpsTaskCreator, SimpleDCAV2 {
    uint256 public count;
    uint256 public lastExecuted;
    bytes32 public taskId;
    uint256 public constant MAX_COUNT = 5;
    uint256 public constant INTERVAL = 3 minutes;

    event CounterTaskCreated(bytes32 taskId);

    constructor(address _ops, address _fundsOwner, TokenAddr[] memory _tokens)
      OpsTaskCreator(_ops, _fundsOwner)
      SimpleDCAV2(_tokens)
    {}

    function createTask() external {
      require(taskId == bytes32(""), "Already started task");

      bytes memory execData = abi.encodeCall(this.invest, ());

      ModuleData memory moduleData = ModuleData({
          modules: new Module[](2),
          args: new bytes[](2)
      });
      moduleData.modules[0] = Module.TIME;
      moduleData.modules[1] = Module.PROXY;

      moduleData.args[0] = _timeModuleArg(block.timestamp, INTERVAL);
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
}