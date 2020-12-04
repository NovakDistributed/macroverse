pragma solidity ^0.6.10;


/**
 * @title OZ1ERC20Basic
 * @dev Old OpenZeppelin 1 ERC20Basic as used in mainnet Macroverse deployment
 */
abstract contract OZ1ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public virtual view returns (uint256);
  function transfer(address to, uint256 value) public virtual;
  event Transfer(address indexed from, address indexed to, uint256 value);
}

// SPDX-License-Identifier: MIT
