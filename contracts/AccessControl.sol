/**
 * Interface for an access control strategy for Macrtoverse contracts.
 * Can be asked if a certain query should be allowed, and will return true or false.
 * Allows for different access control strategies (unrestricted, minimum balance, subscription, etc.) to be swapped in.
 */
contract AccessControl {
    /**
     * Should a query be allowed for this msg.sender (calling contract) and this tx.origin (calling user)?
     */
    function allowQuery(address sender, address origin) public view returns (bool);
}
