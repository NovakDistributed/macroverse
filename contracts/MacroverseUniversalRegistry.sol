pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoEther.sol";
import "./HasNoContracts.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./MacroverseNFTUtils.sol";

/**
 * The MacroverseUniversalRegistry keeps track of who currently owns virtual
 * real estate in the Macroverse world, at all scales. It supersedes the
 * MacroverseStarRegistry.
 *
 * Ownership is based on a claim system, where unowned objects can be claimed
 * by people by putting up a deposit in MRV. The MRV deposit is returned when
 * the owner releases their claim on the corresponding object.
 *
 * The claim system is protected against front-running by a commit/reveal
 * system with a mandatory waiting period. You first commit to the claim you
 * want to make, by putting up the deposit and publishing a hash. After a
 * certain mandatory waiting period, you can reveal what it is you are trying
 * to claim, and actually take ownership of the object.
 *
 * The first person to reveal wins in case two or more people try to claim the
 * same object, or if they try to claim things that are
 * parents/children/overlapping in such a way that the claims conflict. Since
 * there's a mandatory waiting period between the commit and reveal, and since
 * a malicious front-runner cannot commit until they see a reveal they are
 * trying to front-run, then as long as malicious front-runners cannot keep
 * transactions off the chain for the duration of the mandatory wait period,
 * then they can't steal things other people are trying to claim.
 *
 * It's still possible for an organic conflict to end up getting resolved in
 * favor of whoever is willing to pay more for gas, or for people to leave many
 * un-revealed claims and grief people by revealing them when someone else
 * tries to claim the same objects.
 *
 * To further mitigate griefing, committed claims will expire after a while if
 * not revealed.
 *
 * Revealing requires demonstrating that the Macroverse object being claimed
 * actually exists, and so claiming can only be done by people who can pass the
 * Macroverse generator's AccessControl checks.
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
 * The mapping from systems, planets, moons, and land trixels to token ID
 * numbers is defined in the MacroverseNFTUtils library.
 *
 * "Planets" which are asteroid belts and "moons" which are ring systems also
 * are subdivided into 8 triangles, and then recursively into nested sets of 4
 * sub-triangles. However, the initial 8 triangles are defined as wedges, with
 * the points at the central body and with the outer edges being curved. They
 * are numbered prograde, with the division from 0 to 7 corresponding to the
 * object's notional position, computed as if it were a point body with the
 * same orbital parameters. Note that this means that some ownership claims do
 * not actually overlap the orbital range (and thus do not contain anything),
 * and that any actual particles would move relative to the positions of the
 * claims over time, depending on their actual orbits. 
 *
 * At the astronomical level (stars, planets, moons), tokens can be issued
 * for the children of things already claimed, if the lowest owned parent token
 * has homesteading enabled.  At the land level, only one token can cover
 * a given point at a given time, but plots can be subdivided and merged
 * according to the trixel structure.
 *
 * Internally, bookkeeping data is kept to allow the tree of all issued tokens
 * to be traversed. All issued tokens exist in the tree, as well as the
 * internal nodes of the token hierarchy necessary to connect them. The
 * presence of child nodes in the tree is tracked using a bitmap for each node.
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

    using SafeMath for uint256;
    using MacroverseNFTUtils for uint256;

    // These constants are shared with the TokenUtils library

    // Define the types of tokens that can exist
    uint256 constant TOKEN_TYPE_SECTOR = 0;
    uint256 constant TOKEN_TYPE_SYSTEM = 1;
    uint256 constant TOKEN_TYPE_PLANET = 2;
    uint256 constant TOKEN_TYPE_MOON = 3;
    // Land tokens are a range of type field values.
    // Land tokens of the min type use one trixel field
    uint256 constant TOKEN_TYPE_LAND_MIN = 4;
    uint256 constant TOKEN_TYPE_LAND_MAX = 31;

    // Define the packing format
    uint8 constant TOKEN_SECTOR_X_SHIFT = 5;
    uint8 constant TOKEN_SECTOR_X_BITS = 16;
    uint8 constant TOKEN_SECTOR_Y_SHIFT = TOKEN_SECTOR_X_SHIFT + TOKEN_SECTOR_X_BITS;
    uint8 constant TOKEN_SECTOR_Y_BITS = 16;
    uint8 constant TOKEN_SECTOR_Z_SHIFT = TOKEN_SECTOR_Y_SHIFT + TOKEN_SECTOR_Y_BITS;
    uint8 constant TOKEN_SECTOR_Z_BITS = 16;
    uint8 constant TOKEN_SYSTEM_SHIFT = TOKEN_SECTOR_Z_SHIFT + TOKEN_SECTOR_Z_BITS;
    uint8 constant TOKEN_SYSTEM_BITS = 16;
    uint8 constant TOKEN_PLANET_SHIFT = TOKEN_SYSTEM_SHIFT + TOKEN_SYSTEM_BITS;
    uint8 constant TOKEN_PLANET_BITS = 16;
    uint8 constant TOKEN_MOON_SHIFT = TOKEN_PLANET_SHIFT + TOKEN_PLANET_BITS;
    uint8 constant TOKEN_MOON_BITS = 16;
    uint8 constant TOKEN_TRIXEL_SHIFT = TOKEN_MOON_SHIFT + TOKEN_MOON_BITS;
    uint8 constant TOKEN_TRIXEL_EACH_BITS = 3;

    // How many trixel fields are there
    uint256 constant TOKEN_TRIXEL_FIELD_COUNT = 27;

    // How many children does a trixel have?
    uint256 constant CHILDREN_PER_TRIXEL = 4;
    // And how many top level trixels does a world have?
    uint256 constant TOP_TRIXELS = 8;

    // We keep a bit mask of the high bits of all but the least specific trixel.
    // None of these may be set in a valid token.
    // We rely on it being left-shifted TOKEN_TRIXEL_SHIFT bits before being applied.
    // Note that this has 26 1s, with one every 3 bits, except the last 3 bits are 0.
    uint256 constant TOKEN_TRIXEL_HIGH_BIT_MASK = 0x124924924924924924920;

    // Sentinel for no moon used (for land on a planet)
    uint16 constant MOON_NONE = 0xFFFF; 

    //////////////
    // Events for the commit/reveal system
    //////////////

    // Note that in addition to these special events, transfers to/from 0 are
    // fired as tokens are created and destroyed.

    /// Fired when an owner makes a commitment. Includes the commitment hash of token, nonce.
    event Commit(bytes32 indexed hash, address indexed owner);
    /// Fired when a commitment is successfully revealed and the token issued.
    event Reveal(bytes32 indexed hash, uint256 indexed token, address indexed owner);
    /// Fired when a commitment is canceled without being revealed.
    event Cancel(bytes32 indexed hash, address indexed owner);

    /// Fired when a token is released to be claimed by others.
    /// Use this instead of transfers to 0, because those also happen when subdividing/merging land.
    event Release(uint256 indexed token, address indexed former_owner);

    /// Fired when homesteading under a token is enabled or disabled.
    /// Not fired when the token is issued; it starts disabled.
    event Homesteading(uint256 indexed token, bool indexed value);
    /// Fired when a parcel of land is split out of another
    /// Gets emitted once per child.
    event LandSplit(uint256 indexed parent, uint256 indexed child);
    /// Fired when a parcel of land is merged into another.
    /// Gets emitted once per child.
    event LandMerge(uint256 indexed child, uint256 indexed parent);

    /// Fired when the deposit scale for the registry is updated by the administrator.
    event DepositScaleChange(uint256 new_min_system_deposit_in_atomic_units);

    //////////////
    // Contract state
    //////////////

    /// This is the token in which ownership deposits have to be paid.
    IERC20 public depositTokenContract;
    /// This is the minimum ownership deposit in atomic token units.
    uint public minSystemDepositInAtomicUnits;
    
    /// This tracks how much of the deposit token the contract is supposed to have.
    /// If it ends up with extra (because someone incorrectly used transfer() instead of approve()), the owner can remove it.
    uint public expectedDepositBalance;

    /// How long should a commitment be required to sit before it can be revealed, in Ethereum time?
    /// This is also the maximum delay that we can let a bad actor keep good transactions off the chain, in our front-running security model.
    uint public commitmentMinWait;

    /// How long should a commitment be allowed to sit un-revealed before it becomes invalid and can only be canceled?
    /// This protects against unrevealed commitments being used as griefing traps.
    /// This is a multiple of the min wait.
    uint constant COMMITMENT_MAX_WAIT_FACTOR = 7;

    /// A Commitment represents an outstanding attempt to claim a deed.
    /// It also needs to be referenced to look up the deposit associated with an owned token when the token is destroyed.
    /// It is identified by a "key", which is the hash of the committing hash and the owner address.
    /// This is the mapping key under which it is stored.
    /// We don't need to store the owner because the mapping key hash binds the commitment to the owner.
    struct Commitment {
        // Hash (keccak256) of the token we want to claim and a uint256 nonce to be revealed with it.
        bytes32 hash;        
        // Number of atomic token units deposited with the commitment
        uint256 deposit;
        // Time number at which the commitment was created.
        uint256 creationTime;
    }
    
    /// This is all the commitments that are currently outstanding.
    /// The mapping key is keccak256(hash, owner address).
    /// When they are revealed or canceled, they are deleted from the map.
    mapping(bytes32 => Commitment) public commitments;

    /// Tokens have some configuration info to them, beyond what the base ERC721 implementation tracks.
    struct TokenConfig {
        /// This holds the deposit amount associated with the token, which will be released when the token is unclaimed.
        uint256 deposit;
        /// True if the token allows homesteading (i.e. the claiming of child tokens by others)
        bool homesteading;
    }

    /// This holds the TokenConfig for each token
    mapping(uint256 => TokenConfig) tokenConfigs;

    /// This maps from each hierarchical bit-packed keypath entry to a bitmap of
    /// which of its direct children have deed tokens issued at or under them.
    /// If all the bits would be 0, an entry need not exist (which is the
    /// Solidity mapping default behavior).
    mapping (uint256 => uint256) internal childTree;

    /**
     * Deploy a new copy of the Macroverse Universal Registry.
     * The given token will be used to pay deposits, and the given minimum
     * deposit size will be required to claim a star system.
     * Other deposit sizes will be calculated from that.
     * The given min wait time will be the required time you must wait after committing before revealing.
     */
    constructor(address deposit_token_address, uint initial_min_system_deposit_in_atomic_units, uint commitment_min_wait) public ERC721Full("Macroverse Real Estate", "MRE") {
        // We can only use one token for the lifetime of the contract.
        depositTokenContract = IERC20(deposit_token_address);
        // But the minimum deposit for new claims can change
        minSystemDepositInAtomicUnits = initial_min_system_deposit_in_atomic_units;
        // Set the wait time
        commitmentMinWait = commitment_min_wait;
    }

    //////////////
    // Child tree functions
    //////////////

    // First we need some bit utilities

    /**
     * Set the value of a bit by index in a uint256.
     * Bits are counted from the LSB left.
     */
    function setBit(uint256 bitmap, uint256 index, bool value) internal pure returns (uint256) {
        uint256 bit = 0x1 << index;
        if (value) {
            // Set it
            return bitmap | bit;
        } else {
            // Clear it
            return bitmap & (~bit);
        }
    }

    /**
     * Get the value of a bit by index in a uint256.
     * Bits are counted from the LSB left.
     */
    function getBit(uint256 bitmap, uint256 index) internal pure returns (bool) {
        uint256 bit = 0x1 << index;
        return (bitmap & bit != 0);
    }

    /**
     * Register a token/internal node and all parents as having an extant token
     * present under them in the child tree.
     */
    function addChildToTree(uint256 token) internal {
        
        if (token.getTokenType() == TOKEN_TYPE_SECTOR) {
            // No parent exists; we're a tree root.
            return;
        }

        // Find the parent
        uint256 parent = token.parentOfToken();

        // Find what child index we are of the parent
        uint256 child_index = token.childIndexOfToken();
        
        // Get the parent's child tree entry
        uint256 bitmap = childTree[parent];

        if (getBit(bitmap, child_index)) {
            // Stop if the correct bit is set already
            return;
            // TODO: reuse the mask for the bit?
        }

        // Set the correct bit if unset
        childTree[parent] = setBit(bitmap, child_index, true);

        // Continue until we hit the top of the tree
        addChildToTree(parent);
    }

    /**
     * Record in the child tree that a token no longer exists. Also handles
     * cleanup of internal nodes that now have no children.
     */
    function removeChildFromTree(uint256 token) internal {

        if (token.getTokenType() == TOKEN_TYPE_SECTOR) {
            // No parent exists; we're a tree root.
            return;
        }

        // See if we have any children that still exist
        if (childTree[token] == 0) {
            // We are not an existing token ourselves, and we have no existing children.

            // Find the parent
            uint256 parent = token.parentOfToken();

            // Find what child index we are of the parent
            uint256 child_index = token.childIndexOfToken();
            
            // Getmthe parent's child tree entry
            uint256 bitmap = childTree[parent];

            if (getBit(bitmap, child_index)) {
                // Our bit in our immediate parent is set.

                // Clear it
                childTree[parent] = setBit(bitmap, child_index, false);

                if (!_exists(parent)) {
                    // Recurse up to maybe clean up the parent, if we were the
                    // last child and the parent doesn't exist as a token
                    // itself.
                    removeChildFromTree(parent);
                }
            }
        }
    }

    //////////////
    // State-aware token utility functions
    //////////////

    /**
     * Get the lowest-in-the-hierarchy token that exists (is owned).
     * Returns a 0-value sentinel if no parent token exists.
     */
    function lowestExistingParent(uint256 token) public view returns (uint256) {
        if (token.getTokenType() == TOKEN_TYPE_SECTOR) {
            // No parent exists, and we can't exist.
            return 0;
        }

        uint256 parent = token.parentOfToken();

        if (_exists(parent)) {
            // We found a token that really exists
            return parent;
        }

        // Otherwise, recurse on the parent
        return lowestExistingParent(parent);

        // Recursion depth is limited to a reasonable maximum by the maximum
        // depth of the land hierarchy.
    }

    /**
     * Returns true if direct children of the given token can be claimed by the given claimant.
     * Children of land tokens can never be claimed (the plot must be subdivided).
     * Children of system/planet/moon tokens can only be claimed if the claimer owns them or the owner allows homesteading.
     */
    function childrenClaimable(uint256 token, address claimant) public view returns (bool) {
        require(_exists(token));
        return !token.tokenIsLand() && (claimant == ownerOf(token) || tokenConfigs[token].homesteading);
    }

    /**
     * Get the min deposit that will be required to create a claim on a token.
     *
     * Tokens can only exist with deposits smaller than this if they were
     * created before the minimum deposit was raised, or if they are the result
     * of merging other tokens whose deposits were too small.
     */
    function getMinDepositToCreate(uint256 token) public view returns (uint256) {
        // Get the token's type
        uint256 token_type = token.getTokenType();

        if (token_type == TOKEN_TYPE_SECTOR) {
            // Sectors cannot be owned.
            return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        } else if (token_type == TOKEN_TYPE_SYSTEM) {
            // For systems, the deposit is set
            return minSystemDepositInAtomicUnits;
        } else if (token_type == TOKEN_TYPE_PLANET) {
            // For planets, the deposit is a fraction of the system
            return minSystemDepositInAtomicUnits.div(10);
        } else if (token_type == TOKEN_TYPE_MOON) {
            // For moons, the deposit is a smaller fraction
            return minSystemDepositInAtomicUnits.div(30);
        } else {
            // It must be land
            
            // For land, the deposit is smaller and cuts in half with each level of subdivision (starting at 1).
            // So all the small claims is twice as expensive as the big claim.
            uint256 subdivisions = token.getTokenTrixelCount();
            return minSystemDepositInAtomicUnits.div(30) >> subdivisions;
            // TODO: Look at and balance the exact relationships between planet, moon, and whole-surface claim costs.
        }
    }

    /**
     * Return true if the given token exists and the corresponding world object is claimed, and false otherwise.
     * Does not account for owners of parents.
     */
    function exists(uint256 token) public view returns (bool) {
        // Just wrap the private exists function
        return _exists(token);
    }


    //////////////
    // Minting and destruction logic: commit/reveal/cancel and release
    //////////////
    
    /**
     * Make a new commitment by debiting msg.sender's account for the given deposit.
     * Returns the numerical ID of the commitment, which must be passed to
     * reveal() together with the actual bit-packed keypath of the thing being
     * claimed in order to finalize the claim.
     */
    function commit(bytes32 hash, uint256 deposit) external {
        // Deposit size will not be checked until reveal!

        // We use the 0 hash as an indication that a commitment isn't present
        // in the mapping, so we prohibit it here as a real commitment hash.
        require(hash != bytes32(0), "Zero hash prohibited");

        // Record we have the deposit value
        expectedDepositBalance = expectedDepositBalance.add(deposit);

        // Make sure we can take the deposit
        require(depositTokenContract.transferFrom(msg.sender, this, deposit), "Deposit not approved");

        // Compute the commitment key
        bytes32 commitment_key = keccak256(abi.encodePacked(hash, msg.sender));

        // Find the record for it
        Commitment storage commitment = commitments[commitment_key];

        // Make sure it is free
        require(commitment.hash == bytes32(0), "Duplicate commitment prohibited");

        // Fill it in
        commitment.hash = hash;
        commitment.deposit = deposit;
        commitment.creationTime = now;

        // Do an event for tracking.  Nothing needs to come out of this for the
        // reveal; you just need to know that you succeeded and about when.
        emit Commit(hash, msg.sender);
    }

    /**
     * Cancel a commitment that has not yet been revealed.
     * Returns the associated deposit.
     * ID the commitment by the committing hash passed to commit(), *not* the
     * internal key.
     * Must be sent from the same address that created the commitment, or the
     * commitment cannot be addressed.
     */
    function cancel(bytes32 hash) external {
        // We use the 0 hash as an indication that a commitment isn't present
        // in the mapping, so we prohibit it here as a real commitment hash.
        require(hash != bytes32(0), "Zero hash prohibited");

        // Look up the right commitment for this hash and owner.
        bytes32 commitment_key = keccak256(abi.encodePacked(hash, msg.sender));
        Commitment storage commitment = commitments[commitment_key];

        // Make sure it is present with the right nonzero hash.
        // If it seems to have a zero hash, the commitment is gone/never existed.
        require(commitment.hash == hash, "Commitment not found");

        // Work out how much to refund
        uint256 refund = commitment.deposit;

        // Destroy the commitment
        delete commitments[commitment_key];

        // Record we sent the deposit value
        expectedDepositBalance = expectedDepositBalance.sub(refund);

        // Return the deposit
        require(depositTokenContract.transfer(msg.sender, refund));

        // Emit a Cancel event
        emit Cancel(hash, msg.sender);
    }

    /**
     * Finish a commitment by revealing the token we want to claim and the
     * nonce to make the commitment hash. Creates the token. Fails and reverts
     * if the preimage is incorrect, the commitment is expired, the commitment
     * is too new, the commitment is missing, the deposit is insufficient for
     * whatever is being claimed, the Macroverse generators cannot be accessed
     * to prove the existence of the thing being claimed or its parents, or the
     * thing or a child or parent is already claimed by a conflicting
     * commitment. Otherwise issues the token for the bit-packed keypath given
     * in preimage.
     *
     * Doesn't need the commitment hash: it is computed from the provided
     * preimage.  Commitment lookup also depends on the originating address, so
     * the function must be called by the original committer.
     */
    function reveal(uint256 token, uint256 nonce) external {
        // Compute the committing hash that this is the preimage for
        bytes32 hash = keccak256(abi.encodePacked(token, nonce));
        
        // Look up the right commitment for this hash and owner.
        bytes32 commitment_key = keccak256(abi.encodePacked(hash, msg.sender));
        Commitment storage commitment = commitments[commitment_key];

        // Make sure it is present with the right nonzero hash.
        // If it seems to have a zero hash, the commitment is gone/never existed.
        require(commitment.hash == hash, "Commitment not found");
        
        // Make sure the commitment is not expired (max wait is in the future)
        require(commitment.creationTime + (commitmentMinWait * COMMITMENT_MAX_WAIT_FACTOR) > now, "Commitment expired");

        // Make sure the commitment is not too new (min wait is in the past)
        require(commitment.creationTime + commitmentMinWait < now, "Commitment too new");

        // Make sure the token doesn't already exists
        require(!_exists(token), "Token already exists");

        // Validate the token
        require(token.tokenIsCanonical(), "Token data mis-packed");
        // TODO: query the generator to make sure the thing exists

        // Make sure that sufficient tokens have been deposited for this thing to be claimed
        require(commitment.deposit >= getMinDepositToCreate(token), "Deposit too small");

        // Do checks on the parent
        uint256 extant_parent = lowestExistingParent(token);
        if (extant_parent != 0) {
            // A parent exists. Can this person claim its children?
            require(childrenClaimable(extant_parent, msg.sender), "Cannot claim children here");
        }

        // If it's land, no children can be claimed already
        require(!token.tokenIsLand() || childTree[token] == 0, "Cannot claim land with claimed subplots");

        // OK, now we know the claim is valid. Execute it.

        // Create the token state, with homesteading off, carrying over the deposit
        tokenConfigs[token] = TokenConfig({
            deposit: commitment.deposit,
            homesteading: false
        });

        // Record it in the child tree. This informs all parent land tokens
        // that could be created that there are child claims, and blocks them.
        addChildToTree(token);

        // Destroy the commitment
        delete commitments[commitment_key];

        // Emit a reveal event, before actually making the token
        emit Reveal(hash, token, msg.sender);

        // If we pass everything, mint the token
        _mint(msg.sender, token);
    }

    /**
     * Destroy a token that you own, allowing it to be claimed by someone else.
     * Retruns the associated deposit to you.
     */
    function release(uint256 token) external {
        // Burn the token IFF it exists and is owned by msg.sender
        _burn(msg.sender, token);

        // Say the token was released
        emit Release(token, msg.sender);

        // Remove it from the tree so it no longer blocks parent claims if it is land
        removeChildFromTree(token);
        
        // Work out what the deposit was
        uint256 deposit = tokenConfigs[token].deposit;

        // Clean up its config
        delete tokenConfigs[token];

        // Record we sent the deposit back
        expectedDepositBalance = expectedDepositBalance.sub(deposit);

        // Return the deposit
        require(depositTokenContract.transfer(msg.sender, deposit));
    }

    //////////////
    // Token owner functions
    //////////////

    /**
     * Set whether homesteading is allowed under a token. The token must be owned by you, and must not be land.
     */
    function setHomesteading(uint256 token, bool value) external {
        require(ownerOf(token) == msg.sender, "Token owner mismatch");
        require(!token.tokenIsLand());
        
        // Find the token's config
        TokenConfig storage config = tokenConfigs[token];

        if (config.homesteading != value) {
            // The value is actually changing

            // Set the homesteading flag
            config.homesteading = value;

            // Make an event so clients can find homesteading areas
            emit Homesteading(token, value);
        }
    }

    /**
     * Get whether homesteading is allowed under a token.
     * Returns false for nonexistent or invalid tokens.
     */
    function getHomesteading(uint256 token) external view returns (bool) {
        // Only existing non-land tokens with homesteading on can be homesteaded.
        return (_exists(token) && !token.tokenIsLand() && tokenConfigs[token].homesteading); 
    }

    /**
     * Get the deposit tied up in a token, in MRV atomic units.
     * Returns 0 for nonexistent or invalid tokens.
     * Deposits associated with claims need to be gotten by looking at the claim mapping directly.
     */
    function getDeposit(uint256 token) external view returns (uint256) {
        // Only existing non-land tokens with homesteading on can be homesteaded.
        if (!_exists(token)) {
            return 0;
        }
        return tokenConfigs[token].deposit;
    }

    /**
     * Split a trixel of land into 4 sub-trixel tokens.
     * The new tokens will be owned by the same owner.
     * The old token will be destroyed.
     * Additional deposit may be required so that all subdivided tokens have at least the minimum deposit.
     * The deposit from the original token will be re-used if possible.
     * If the deposit available is not divisible by 4, the extra will be assigned to the first child token.
     */
    function subdivideLand(uint256 parent, uint256 additional_deposit) external {
        // Make sure the parent is land owned by the caller.
        // If a token is owned, it must be canonical.
        require(ownerOf(parent) == msg.sender, "Token owner mismatch");

        // Make sure the parent isn't maximally subdivided
        require(parent.getTokenType() != TOKEN_TYPE_LAND_MAX, "Land maximally subdivided");

        // Get the deposit from it
        uint256 deposit = tokenConfigs[parent].deposit;

        // Take the new deposit from the caller
        // Record we have the deposit value
        expectedDepositBalance = expectedDepositBalance.add(additional_deposit);

        // Make sure we can take the deposit
        require(depositTokenContract.transferFrom(msg.sender, this, additional_deposit), "Deposit not approved");

        // Add in the new deposit
        deposit = deposit.add(additional_deposit);

        // Compute the token numbers for the new child tokens
        uint256[] memory children = new uint256[](CHILDREN_PER_TRIXEL);
        // And their deposits. In theory they might vary by token identity.
        uint256[] memory child_deposits = new uint256[](CHILDREN_PER_TRIXEL);
        // And the total required
        uint256 required_deposit = 0;
        for (uint256 i = 0; i < CHILDREN_PER_TRIXEL; i++) {
            uint256 child = parent.childTokenAtIndex(i);
            children[i] = child;
            uint256 child_deposit = getMinDepositToCreate(child);
            child_deposits[i] = child_deposit;
            required_deposit = required_deposit.add(child_deposit);
        }

        require(required_deposit <= deposit, "Deposit not sufficient");

        // Burn the parent
        _burn(msg.sender, parent);

        // Clean up its config
        delete tokenConfigs[parent];

        // Apportion deposit and create the children

        // Now deposit will be is the remaining deposit to try and distribute evenly among the children
        deposit = deposit.sub(required_deposit);
        uint256 split_evenly = deposit.div(CHILDREN_PER_TRIXEL);
        uint256 extra = deposit.mod(CHILDREN_PER_TRIXEL);
        child_deposits[0] = child_deposits[0].add(extra);
        for (i = 0; i < CHILDREN_PER_TRIXEL; i++) {
            child_deposits[i] = child_deposits[i].add(split_evenly);

            // Now we can make the child token config
            tokenConfigs[children[i]] = TokenConfig({
                deposit: child_deposits[i],
                homesteading: false
            });

            // Say land is being split
            emit LandSplit(parent, children[i]);

            // And mint the child
            _mint(msg.sender, children[i]);
        }

        // Set the parent's entry in the child tree to having all 4 children.
        // Its parent will still record its presence.
        childTree[parent] = 0xf;
    }

    /**
     * Combine 4 land tokens with the same parent trixel into one token for the parent trixel.
     * Tokens must all be owned by the message sender.
     * Allows withdrawing some of the deposit of the original child tokens, as long as sufficient deposit is left to back the new parent land claim.
     */
    function combineLand(uint256 child1, uint256 child2, uint256 child3, uint256 child4, uint256 withdraw_deposit) external {
        // Make a child array
        uint256[CHILDREN_PER_TRIXEL] memory children = [child1, child2, child3, child4];

        // And count up the deposit they represent
        uint256 available_deposit = 0;
        
        for (uint256 i = 0; i < CHILDREN_PER_TRIXEL; i++) {
            // Make sure all the children are owned by the caller
            require(ownerOf(children[i]) == msg.sender, "Token owner mismatch");
            // If a token is owned, it must be canonical.

            // Collect the deposit
            available_deposit = available_deposit.add(tokenConfigs[children[i]].deposit);
        }
        
        // Make sure all the children are distinct
        require(children[0] != children[1], "Children not distinct");
        require(children[0] != children[2], "Children not distinct");
        require(children[0] != children[3], "Children not distinct");

        require(children[1] != children[2], "Children not distinct");
        require(children[1] != children[3], "Children not distinct");

        require(children[2] != children[3], "Children not distinct");
        
        // Make sure they are all children of the same parent
        uint256 parent = children[0].parentOfToken();
        for (i = 1; i < CHILDREN_PER_TRIXEL; i++) {
            require(children[i].parentOfToken() == parent, "Parent not shared");
        }
        
        // Make sure that that parent is land
        require(parent.tokenIsLand());

        // Compute the parent deposit
        uint256 parent_deposit = available_deposit.sub(withdraw_deposit);

        // Edge case: min deposit scale was adjusted and now the deposits for
        // the children aren't enough for the parent.
        // In that case, we allow the merge, but withdraw_deposit must be 0.
        if (withdraw_deposit > 0) {
            require(parent_deposit >= getMinDepositToCreate(parent), "Deposit not sufficient");
        }

        for (i = 0; i < CHILDREN_PER_TRIXEL; i++) {
            // Burn the children
            _burn(msg.sender, children[i]);

            // Clean up the config
            delete tokenConfigs[children[i]];

            // Say land is being merged
            emit LandSplit(children[i], parent);
        }

        // Make a parent config
        tokenConfigs[parent] = TokenConfig({
            deposit: parent_deposit,
            homesteading: false
        });

        // Create the parent
        _mint(msg.sender, parent);

        // Set the parent's entry in the child tree to having no children.
        // Its parent will still record its presence as an internal node.
        childTree[parent] = 0;

        // Return the requested amount of returned deposit.

        // Record we sent the deposit back
        expectedDepositBalance = expectedDepositBalance.sub(withdraw_deposit);

        // Return the deposit
        require(depositTokenContract.transfer(msg.sender, withdraw_deposit));
    }

    //////////////
    // Admin functions
    //////////////

    /**
     * Allow the contract owner to set the minimum deposit amount for granting new
     * system ownership claims.
     */
    function setMinimumSystemDeposit(uint256 new_minimum_deposit_in_atomic_units) external onlyOwner {
        minSystemDepositInAtomicUnits = new_minimum_deposit_in_atomic_units;
        emit DepositScaleChange(minSystemDepositInAtomicUnits);
    }
    
    /**
     * Allow the owner to collect any non-MRV tokens, or any excess MRV, that ends up in this contract.
     */
    function reclaimToken(address otherToken) external onlyOwner {
        IERC20 other = IERC20(otherToken);
        
        // We will send our whole balance
        uint excessBalance = other.balanceOf(this);
        
        // Unless we're talking about the MRV token
        if (address(other) == address(depositTokenContract)) {
            // In which case we send only any balance that we shouldn't have
            excessBalance = excessBalance.sub(expectedDepositBalance);
        }
        
        // Make the transfer. If it doesn't work, we can try again later.
        other.transfer(owner(), excessBalance);
    }
}
