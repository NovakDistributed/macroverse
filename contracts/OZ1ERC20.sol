pragma solidity ^0.6.10;


import './OZ1ERC20Basic.sol';


/**
 * @title Old OpenZeppelin 1 ERC20 as used in mainnet Macroverse deployment
 */
abstract contract OZ1ERC20 is OZ1ERC20Basic {
  function allowance(address owner, address spender) public virtual view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public virtual;
  function approve(address spender, uint256 value) public virtual;
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
