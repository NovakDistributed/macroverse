pragma solidity ^0.4.24;

import "./MRVToken.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoEther.sol";
import "./HasNoContracts.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
 * The MacroverseUniversalRegistry keeps track of who currently owns virtual
 * real estate in the Macroverse world, at all scales. It supersedes the
 * MacroverseStarRegistry.
 *
 * Ownership is handled by having the first person who wants to own an object
 * claim it, by putting up a deposit in MRV tokens of a certain minimum size.
 * Note that the owner of the contract reserves the right to adjust this
 * minimum size at any time, for any reason, and without notice. Since the size
 * of the deposit to be made is specified by the claimant, trying to claim
 * something when the minimum deposit size has been increased without your
 * knowledge should at worst result in wasted gas.
 *
 * The claiming system is protected against front-running by a commit/reveal
 * process. When you reveal, you will take the object away from anyone who
 * currently has it with a later priority date than your commit. This may cause
 * trouble for you if you claim an object and sell it, and then someone comes
 * by with an earlier commit on the object and takes it away from your
 * customer.
 *
 * Revealing requires demonstrating that the Macroverse object being claimed
 * actually exists, and so claiming can only be done by people who can pass the
 * Macroverse generator's AccessControl checks.
 *
 * Owners of objects can send them to other addresses, and an owner can
 * abdicate ownership of an object and collect the original MRV deposit used to
 * claim it.
 *
 * Note that ownership of a star system does not necessarily imply ownership of
 * everything in it. Just as one person can own a condo in another person's
 * building, one person can own a planet in another person's star system.
 * Non-containment of different ownership claims is only enforced for claims of
 * land on planets and moons.
 *
 * The surface of a world is subdivided using a Hierarchical Triangular Mesh
 * approach, as described in <http://www.skyserver.org/HTM/> and in
 * <https://www.microsoft.com/en-us/research/wp-content/uploads/2005/09/tr-2005-123.pdf>
 * "Indexing the Sphere with the Hierarchical Triangular Mesh". At the top
 * level, the surface of a world is an octahedron of equilateral triangles.
 * Each triangle is then recursively subdivided into 4 children by inscribing
 * another equilateral triangle between the center points of its edges. Each
 * HTM "trixel" is a plot of virtual real estate that can be claimed. Land
 * trixels can be subdivided and merged, and ownership of a trixel implies
 * ownership of all contained trixels, because this logic can be done without
 * any reference to the AccessControl-protected Macroverse generator logic.
 *
 * NFT tokens carry metadata about the object they describe, in the form of a
 * bit-packed keypath in the 160 low bits of a uint256:
 *
 * - sector x (16)
 * - sector y (16)
 * - sector z (16)
 * - star number (16)
 * - planet number (16) or all 1s (-1) if not used
 * - moon number (16) or -1 if not used
 * - trixel number (64) or all 0s if not used
 *
 * The trixel number is right-justified, and is encoded as a leading 1, then 3
 * bits for the top-level trixel, and then 2 bits for each subdivision that is
 * used, up to 30 subdivisions.
 *
 * At the astronomical level (stars, planets, moons), deed tokens can be issued
 * for the children of things already claimed.  At the land level, only one
 * deed token can cover a given point at a given time.
 *
 * The deployer of this contract reserves the right to supersede it with a new
 * version at any time, for any reason, and without notice. The deployer of
 * this contract reserves the right to leave it in place as is indefinitely.
 *
 * The deployer of this contract reserves the right to claim and keep any
 * tokens or ETH or contracts sent to this contract, in excess of the MRV
 * balance that this contract thinks it is supposed to have.
 */
contract MacroverseUniversalRegistry is Ownable, HasNoEther, HasNoContracts, ERC721Full {
    // This is the token in which ownership deposits have to be paid.
    MRVToken public tokenAddress;
    // This is the minimum ownership deposit in atomic token units.
    uint public minDepositInAtomicUnits;
    
    // This tracks how much MRV the contract is supposed to have.
    // If it ends up with extra (because someone incorrectly used transfer() instead of approve()), the owner can remove it.
    uint public expectedMrvBalance;

    // This maps from each hierarchical bit-packed keypath entry to a bitmap of
    // which of its direct children have deed tokens issued at or under them.
    // If all the bits would be 0, an entry need not exist (which is the
    // Solidity mapping default behavior).
    mapping (uint256 => uint256) internal childDeedFlags;

    // How long should a commitment be valid before needing to be revealed or destroyed and re-created, in Ethereum time?
    // This is the same timeout that we need to wait for a land registration to become unchallengeable (because all prior commitments expired).
    uint public commitmentTimeout = 1 days;

    /// A Commitment represents an outstanding attempt to claim a deed.
    struct Commitment {
        // msg.sender making the commitment, who is the only one who can reveal on it.
        address owner;
        // Hash (keccak256) of the token we want to claim and a uint256 salt to be revealed with it.
        bytes32 hash;
        // Number of atomic token units deposited with the commitment
        uint256 deposit;
        // Time number at which the commitment was created.
        // Commitments expire a certain amount of time after creation.
        uint256 creationTime;
    }
    
    /// This is all the commitments that have ever been made
    Commitment[] public commitments;

    /// This is the commitment ID for each outstanding token.
    /// It gives the priority date/creation tiem fro the token, for resolving commitment conflicts.
    mapping (uint256 => uint256) internal tokenToCommitment;

    /**
     * Deploy a new copy of the Macroverse Universal Registry.
     * The given token will be used to pay deposits, and the given minimum
     * deposit size will be required.
     */
    constructor(address depositTokenAddress, uint initialMinDepositInAtomicUnits) public {
        // We can only use one token for the lifetime of the contract.
        tokenAddress = MRVToken(depositTokenAddress);
        // But the minimum deposit for new claims can change
        minDepositInAtomicUnits = initialMinDepositInAtomicUnits;
    }
    
    /**
     * Make a new commitment by debiting msg.sender's account for the given deposit.
     * Returns the numerical ID of the commitment, which must be passed to
     * reveal() together with the actual bit-packed keypath of the thing being
     * claimed in order to finalize the claim.
     */
    function commit(bytes32 hash, uint256 deposit) external returns (uint256 commitmentID) {
        // Make sure they are depositing enough
        require(deposit > minDepositInAtomicUnits);

        // Make sure we can take the money
        require(tokenAddress.transferFrom(msg.sender, deposit));

        // Determine the ID
        commitmentID = commitments.length;
        // Push the commitment
        commitments.push(Commitment({
            owner: msg.sender,
            hash: hash,
            deposit: deposit,
            creationTime: now
        }));

        // TODO: Do an event for easy lookup so the frontend can reveal
    }

    /**
     * Finish a commitment by revealing the token we want to claim and the salt to make the commitment hash.
     * Fails and reverts if the preimage is incorrect, the commitment is
     * expired, the commitment is not owned by the msg.sender trying to do the
     * reveal, the deposit is insufficient for whatever is being claimed, the
     * Macroverse generators cannot be accessed to prove the existence of the
     * thing being claimed or its parents, or the thing or a child or parent is
     * already claimed by an earlier conflicting commitment.
     * Otherwise issues the token for the bit-packed keypath given in preimage.
     */
    function reveal(uint256 commitmentID, uint256 token, uint256 salt) external {
        // Make sure the commitment exists
        require(commitmentID < commitments.length);
        // Find it
        Commitment storage commitment = commitments[commitmentID];

        // Make sure the commitment belongs to this person.
        // Otherwise just anyone could steal the preimage.
        require(commitment.owner == msg.sender, "Commitment owner mismatch");
        
        // Make sure the commitment is not expired
        require(commitment.creationTime + commitmentTimeout < now, "Commitment expired");

        // Make sure this is really the token that was committed to
        require(commitment.hash == keccak256(abi.encodePacked(token, salt)), "Commitment hash mismatch");

        if (_exists(token)) {
            // There's a conflict for this token in particular
            uint256 otherCommitmentID = tokenToCommitment[token];
            // We can just compare the commitment IDs in sequence. Smaller wins.
            require(commitmentID < otherCommitmentID, "Already claimed with better priority");
            
            // Now steal the token because we are earlier.
            // TODO: Does OpenZeppelin support some people causing other people's tokens to explode?
            // The OZ way to do this appears to be to destroy it.
            _burn(commitments[commitmentID].owner, token);
        }

        // Save our commitment as the commitment for this token
        tokenToCommitment[token] = commitmentID;
        
        // TODO: Make sure the token exists in the Macroverse world.
        // This part requires the transaction as a whole to pass Macroverse access control.
        // Also we should validate that the trixel number is well-formed

        // TODO: Allow claims within an astronomical parent only if that parent is unclaimed or set to allow child claims.

        if (isLand(token)) {
            // Land claims can't ever overlap.

            // TODO: Check down from the top level to here for containing land claims.
            // If they're later, destroy them.
            // If they're earlier, fail.

            // TODO: Check below here for contained land claims
            // If they're later, destroy them.
            // If they're earlier, fail.
            // TODO: What if someone claims 1000 tiny things between our commit and reveal?
            // We can't destroy all of them!
            // TODO: We need to adopt a three-phase commit reveal claim system
            // You can't claim until all potential conflicts are revealed, so we can check priority and conflicts and only the winner can claim
        }

        // TODO: Register this token under all its parents.

        // If we pass everything, mint the token
        _mint(msg.sender, token);

    }

    /**
     * Return true if the given token number/bit-packed keypath corresponds to a land trixel, and false otherwise.
     */
    function isLand(uint256 token) internal pure returns (bool) {
        // The land texel number lives in the low 64 bits.
        // So anything with data there is a land claim.
        // TODO: It may not be a valid land claim. e.g. 1 is not valid because of the leading-1 rule.
        return (token & 0xFFFFFFFFFFFFFFFF) > 0;
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
