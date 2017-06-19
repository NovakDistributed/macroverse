pragma solidity ^0.4.11;

import "./AccessControl.sol";

import "./zeppelin/ownership/Ownable.sol";

/**
 * Represents a contract that is Ownable, and which has methods that are to be protected by an AccessControl strategy selected by the owner.
 */
contract ControlledAccess is Ownable {

    // This AccessControl contract determines who can run onlyControlledAccess methods.
    AccessControl accessControl;
    
    /**
     * Make a new ControlledAccess contract, controlling access with the given AccessControl strategy.
     */
    function ControlledAccess(address originalAccessControl) {
        accessControl = AccessControl(originalAccessControl);
    }
    
    /**
     * Change the access control strategy of the prototype.
     */
    function changeAccessControl(address newAccessControl) onlyOwner {
        accessControl = AccessControl(newAccessControl);
    }
    
    /**
     * Only allow queries approved by the access control contract.
     */
    modifier onlyControlledAccess {
        if (!accessControl.allowQuery(msg.sender, tx.origin)) throw;
        _;
    }
    

}