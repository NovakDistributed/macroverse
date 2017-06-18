pragma solidity ^0.4.11;

import "./zeppelin/token/ERC20.sol";

import "./AccessControl.sol";


/**
 * Represents an access control strategy where any end user (origin) with a minimum balance in an ERC20 token is allowed.
 */
contract MinimumBalanceAccessControl {
    ERC20 tokenAddress;
    uint minBalanceInAtomicUnits;
    
    function MinimumBalanceAccessControl(address _tokenAddress, uint _minBalanceInAtomicUnits) {
        tokenAddress = ERC20(_tokenAddress);
        minBalanceInAtomicUnits = _minBalanceInAtomicUnits;
    }
    
    function allowQuery(address sender, address origin) constant returns (bool) {
        if (tokenAddress.balanceOf(origin) >= minBalanceInAtomicUnits) {
            return true;
        }
        return false;
    }
}