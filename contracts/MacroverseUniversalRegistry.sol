pragma solidity ^0.4.24;

import "./MRVToken.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoEther.sol";
import "./HasNoContracts.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
 * The Macroverse Star Registry keeps track of who currently owns virtual real estate in the
 * Macroverse world, at all scales. It supersedes the MacroverseStarRegistry.
 *
 * Ownership is handled by having the first person who wants to own an object claim it, by
 * putting up a deposit in MRV tokens of a certain minimum size. Note that the owner of the
 * contract reserves the right to adjust this minimum size at any time, for any reason, and
 * without notice. Since the size of the deposit to be made is specified by the claimant,
 * trying to claim something when the minimum deposit size has been increased without your
 * knowledge should at worst result in wasted gas.
 *
 * The claiming system is protected against front-running by a commit/reveal
 * process. When you reveal, you will take the object away from anyone who
 * currently has it with a later priority date than your commit. This may cause
 * trouble for you if you claim an object and sell it, and then someone comes
 * by with an earlier commit on the object and takes it away from your
 * customer!
 *
 * Owners of objects can send them to other addresses, and an owner can abdicate ownership of
 * an object and collect the original MRV deposit used to claim it.
 *
 * Note that ownership of a star system does not necessarily imply ownership of everything in it.
 * Just as one person can own a condo in another person's building, one person can own a planet in
 * another person's star system.
 *
 * NFT tokens carry metadata about the object they describe, in the form of a keypath:
 *
 * <sector x>.<sector y>.<sector z>.<star number>.<planet number>.<moon number>
 *
 * The deployer of this contract reserves the right to supersede it with a new version at any time,
 * for any reason, and without notice. The deployer of this contract reserves the right to leave it
 * in place as is indefinitely.
 *
 * The deployer of this contract reserves the right to claim and keep any tokens or ETH or contracts
 * sent to this contract, in excess of the MRV balance that this contract thinks it is supposed to
 * have.
 */
contract MacroverseUniversalRegistry is Ownable, HasNoEther, HasNoContracts, ERC721Full {
    // This is the token in which ownership deposits have to be paid.
    MRVToken public tokenAddress;
    // This is the minimum ownership deposit in atomic token units.
    uint public minDepositInAtomicUnits;
    
    // This tracks how much MRV the contract is supposed to have.
    // If it ends up with extra (because someone incorrectly used transfer() instead of approve()), the owner can remove it.
    uint public expectedMrvBalance;
    
    /**
     * Deploy a new copy of the Macroverse Universal Registry.
     * The given token will be used to pay deposits, and the given minimum
     * deposit size will be required.
     */
    constructor(address depositTokenAddress, uint initialMinDepositInAtomicUnits) {
        // We can only use one token for the lifetime of the contract.
        tokenAddress = MRVToken(depositTokenAddress);
        // But the minimum deposit for new claims can change
        minDepositInAtomicUnits = initialMinDepositInAtomicUnits;
    }
    
    /**
     * Allow the owner to set the minimum deposit amount for granting new
     * ownership claims.
     */
    function setMinimumDeposit(uint newMinimumDepositInAtomicUnits) external onlyOwner {
        minDepositInAtomicUnits = newMinimumDepositInAtomicUnits;
    }
    
    /**
     * Allow the owner to collect any non-MRV tokens, or any excess MRV, that ends up in this contract.
     */
    function reclaimToken(address otherToken) external onlyOwner {
        IERC20 other = IERC20(otherToken);
        
        // We will send our whole balance
        uint excessBalance = other.balanceOf(this);
        
        // Unless we're talking about the MRV token
        if (address(other) == address(tokenAddress)) {
            // In which case we send only any balance that we shouldn't have
            excessBalance = excessBalance.sub(expectedMrvBalance);
        }
        
        // Make the transfer. If it doesn't work, we can try again later.
        other.transfer(owner(), excessBalance);
    }
}
