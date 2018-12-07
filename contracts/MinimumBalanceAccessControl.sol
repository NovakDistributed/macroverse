pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./AccessControl.sol";


/**
 * Represents an access control strategy where any end user (origin) with a minimum balance in an ERC20 token is allowed.
 */
contract MinimumBalanceAccessControl {
    IERC20 tokenAddress;
    uint minBalanceInAtomicUnits;
    
    /**
     * Make a new MinimumBalanceAccessControl that requires the specified minimum balance of the specified token.
     */
    constructor(address tokenAddress_, uint minBalanceInAtomicUnits_) public {
        tokenAddress = IERC20(tokenAddress_);
        minBalanceInAtomicUnits = minBalanceInAtomicUnits_;
    }
    
    /**
     * Allow all queries resulting from a transaction initiated from an origin address with at least the required minimum balance.
     * This means that any contract you use can make queries on your behalf, but that no contract with the minimum balance can proxy
     * queries for others.
     */
    function allowQuery(address /* sender */, address origin) public constant returns (bool) {
        if (tokenAddress.balanceOf(origin) >= minBalanceInAtomicUnits) {
            return true;
        }
        return false;
    }
}
