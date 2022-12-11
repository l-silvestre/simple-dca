// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
pragma abicoder v2;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IWETH is IERC20 {
  function deposit() external payable;
  function withdraw(uint amount) external;
}