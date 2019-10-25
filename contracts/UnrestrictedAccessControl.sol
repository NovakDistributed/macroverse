pragma solidity ^0.5.2;

import "./AccessControl.sol";

/**
 * Represents an access control strategy where all requests are accepted.
 */
contract UnrestrictedAccessControl {
    /**
     * Always approve access, ignoring the addresses passed in.
     * Note that this raises solidity compiler warnings about unused variables.
     */
    function allowQuery(address /* sender */, address /* origin */) public pure returns (bool) {
        return true;
    }
}
