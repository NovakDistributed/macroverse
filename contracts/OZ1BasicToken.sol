pragma solidity ^0.6.10;


import './OZ1ERC20Basic.sol';
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/**
 * @title Old OpenZeppelin 1 BasicToken as used in mainnet Macroverse deployment
 */
contract OZ1BasicToken is OZ1ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint256 size) {
     if(msg.data.length < size + 4) {
       revert();
     }
     _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public override onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public override view returns (uint256 balance) {
    return balances[_owner];
  }

}

// SPDX-License-Identifier: MIT
