pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoEther.sol";
import "./HasNoContracts.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

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
 * NFT tokens carry metadata about the object they describe, in the form of a
 * bit-packed keypath in the 192 low bits of a uint256. Form LOW to HIGH bits,
 * the fields are:
 *
 * - token type (5): sector (0), system (1), planet (2), moon (3),
 *   land on planet or moon at increasing granularity (4-31)
 * - sector x (16)
 * - sector y (16)
 * - sector z (16)
 * - star number (16) or 0 if a sector
 * - planet number (16) or 0 if a star
 * - moon number (16) or 0 if a planet, or -1 if land on a planet
 * - 0 to 27 trixel numbers, at 3 bits each
 *
 * More specific claims use more of the higher-value bits, producing larger
 * numbers in general.
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

    //////////////
    // Code for working on token IDs
    //////////////
    
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

    /**
     * Work out what type of real estate a token represents.
     * Land claims of different granularities are different types.
     */
    function getTokenType(uint256 token) internal pure returns (uint256) {
        // Grab off the low 5 bits
        return token & 0x1F;
    }

    /**
     * Modify the type of a token. Does not fix up the other fields to correspond to the new type
     */
    function setTokenType(uint256 token, uint256 newType) internal pure returns (uint256) {
        assert(newType <= 31);
        // Clear and replace the low 5 bits
        return (token & ~uint256(0x1F)) | newType;
    }

    /**
     * Get the 16 bits of the token, at the given offset from the low bit.
     */
    function getTokenUInt16(uint256 token, uint8 offset) internal pure returns (uint16) {
        return uint16(token >> offset);
    }

    /**
     * Set the 16 bits of the token, at the given offset from the low bit, to the given value.
     */
    function setTokenUInt16(uint256 token, uint8 offset, uint16 data) internal pure returns (uint256) {
        // Clear out the bits we want to set, and then or in their values
        return (token & ~(uint256(0xFFFF) << offset)) | (uint256(data) << offset);
    }

    /**
     * Get the X, Y, and Z coordinates of a token's sector.
     */
    function getTokenSector(uint256 token) internal pure returns (int16 x, int16 y, int16 z) {
        x = int16(getTokenUInt16(token, TOKEN_SECTOR_X_SHIFT));
        y = int16(getTokenUInt16(token, TOKEN_SECTOR_Y_SHIFT));
        z = int16(getTokenUInt16(token, TOKEN_SECTOR_Z_SHIFT));
    }

    /**
     * Set the X, Y, and Z coordinates of the sector data in the given token.
     */
    function setTokenSector(uint256 token, int16 x, int16 y, int16 z) internal pure returns (uint256) {
        return setTokenUInt16(setTokenUInt16(setTokenUInt16(token, TOKEN_SECTOR_X_SHIFT, uint16(x)),
            TOKEN_SECTOR_Y_SHIFT, uint16(y)), TOKEN_SECTOR_Z_SHIFT, uint16(z));
    }

    /**
     * Get the system number of a token.
     */
    function getTokenSystem(uint256 token) internal pure returns (uint16) {
        return getTokenUInt16(token, TOKEN_SYSTEM_SHIFT);
    }

    /**
     * Set the system number of a token.
     */
    function setTokenSystem(uint256 token, uint16 system) internal pure returns (uint256) {
        return setTokenUInt16(token, TOKEN_SYSTEM_SHIFT, system);
    }

    /**
     * Get the planet number of a token.
     */
    function getTokenPlanet(uint256 token) internal pure returns (uint16) {
        return getTokenUInt16(token, TOKEN_PLANET_SHIFT);
    }

    /**
     * Set the planet number of a token.
     */
    function setTokenPlanet(uint256 token, uint16 planet) internal pure returns (uint256) {
        return setTokenUInt16(token, TOKEN_PLANET_SHIFT, planet);
    }

    /**
     * Get the moon number of a token.
     */
    function getTokenMoon(uint256 token) internal pure returns (uint16) {
        return getTokenUInt16(token, TOKEN_MOON_SHIFT);
    }

    /**
     * Set the moon number of a token.
     */
    function setTokenMoon(uint256 token, uint16 moon) internal pure returns (uint256) {
        return setTokenUInt16(token, TOKEN_MOON_SHIFT, moon);
    }

    /**
     * Get the number of used trixel fields in a token. From 0 (not land) to 27.
     */
    function getTokenTrixelCount(uint256 token) internal pure returns (uint256) {
        uint256 token_type = getTokenType(token);
        if (token_type < TOKEN_TYPE_LAND_MIN) {
            return 0;
        }
    
        // Remember that at the min type one trixel is used.
        return token_type - TOKEN_TYPE_LAND_MIN + 1;
    }

    /**
     * Set the number of used trixel fields in a token. From 1 to 27.
     * Automatically makes the token land type.
     */
    function setTokenTrixelCount(uint256 token, uint256 count) internal pure returns (uint256) {
        assert(count > 0);
        assert(count <= TOKEN_TRIXEL_FIELD_COUNT);
        uint256 token_type = TOKEN_TYPE_LAND_MIN + count - 1;
        return setTokenType(token, token_type);
    }

    /**
     * Get the value of the trixel at the given index in the token. Index can be from 0 through 26.
     * At trixel 0, values are 0-7. At other trixels, values are 0-3.
     * Assumes the token is land and has sufficient trixels to query this one.
     */
    function getTokenTrixel(uint256 token, uint256 trixel_index) internal pure returns (uint256) {
        assert(trixel_index < TOKEN_TRIXEL_FIELD_COUNT);
        // Shift down to the trixel we want and get the low 3 bits.
        return (token >> (TOKEN_TRIXEL_SHIFT + TOKEN_TRIXEL_EACH_BITS * trixel_index)) & 0x7;
    }

    /**
     * Set the value of the trixel at the given index. Trixel indexes can be
     * from 0 throug 26. Values can be 0-7 for the first trixel, and 0-3 for
     * subsequent trixels.  Assumes the token trixel count will be updated
     * separately if necessary.
     */
    function setTokenTrixel(uint256 token, uint256 trixel_index, uint256 value) internal pure returns (uint256) {
        assert(trixel_index < TOKEN_TRIXEL_FIELD_COUNT);
        if (trixel_index == 0) {
            assert(value < TOP_TRIXELS);
        } else {
            assert(value < CHILDREN_PER_TRIXEL);
        }
        
        // Compute the bit shift distance
        uint256 trixel_shift = (TOKEN_TRIXEL_SHIFT + TOKEN_TRIXEL_EACH_BITS * trixel_index);
    
        // Clear out the field and then set it again
        return (token & ~(uint256(0x7) << trixel_shift)) | (value << trixel_shift); 
    }

    /**
     * Return true if the given token number/bit-packed keypath corresponds to a land trixel, and false otherwise.
     */
    function tokenIsLand(uint256 token) internal pure returns (bool) {
        uint256 token_type = getTokenType(token);
        return (token_type >= TOKEN_TYPE_LAND_MIN && token_type <= TOKEN_TYPE_LAND_MAX); 
    }

    /**
     * Get the token number representing the parent of the given token (i.e. the system if operating on a planet, etc.).
     * That token may or may not be currently owned.
     * May return a token representing a sector; sectors can't be claimed.
     * Will fail if called on a token that is a sector
     */
    function parentOfToken(uint256 token) internal pure returns (uint256) {
        uint256 token_type = getTokenType(token);

        assert(token_type != TOKEN_TYPE_SECTOR);

        if (token_type == TOKEN_TYPE_SYSTEM) {
            // Zero out the system and make it a sector token
            return setTokenType(setTokenSystem(token, 0), TOKEN_TYPE_SECTOR);
        } else if (token_type == TOKEN_TYPE_PLANET) {
            // Zero out the planet and make it a system token
            return setTokenType(setTokenPlanet(token, 0), TOKEN_TYPE_SYSTEM);
        } else if (token_type == TOKEN_TYPE_MOON) {
            // Zero out the moon and make it a planet token
            return setTokenType(setTokenMoon(token, 0), TOKEN_TYPE_PLANET);
        } else if (token_type == TOKEN_TYPE_LAND_MIN) {
            // Move from top level trixel to planet or moon
            if (getTokenMoon(token) == MOON_NONE) {
                // It's land on a planet
                // Make sure to zero out the moon field
                return setTokenType(setTokenMoon(setTokenTrixel(token, 0, 0), 0), TOKEN_TYPE_PLANET);
            } else {
                // It's land on a moon. Leave the moon in.
                return setTokenType(setTokenTrixel(token, 0, 0), TOKEN_TYPE_PLANET);
            }
        } else {
            // It must be land below the top level
            uint256 last_trixel = getTokenTrixelCount(token) - 1;
            // Clear out the last trixel and pop it off
            return setTokenTrixelCount(setTokenTrixel(token, last_trixel, 0), last_trixel);
        }
    }

    /**
     * If the token has a parent, get the token's index among all children of the parent.
     * Planets have surface trixels and moons as children; the 8 surface trixels come first, followed by any moons. 
     * Fails if the token has no parent.
     */
    function childIndexOfToken(uint256 token) internal pure returns (uint256) {
        uint256 token_type = getTokenType(token);

        assert(token_type != TOKEN_TYPE_SECTOR);

        if (token_type == TOKEN_TYPE_SYSTEM) {
            // Get the system field of a system token
            return getTokenSystem(token);
        } else if (token_type == TOKEN_TYPE_PLANET) {
            // Get the planet field of a planet token
            return getTokenPlanet(token);
        } else if (token_type == TOKEN_TYPE_MOON) {
            // Get the moon field of a moon token. Offset it by the 0-7 top trixels of the planet's land.
            return getTokenMoon(token) + TOP_TRIXELS;
        } else if (token_type >= TOKEN_TYPE_LAND_MIN && token_type <= TOKEN_TYPE_LAND_MAX) {
            // Get the value of the last trixel. Top-level trixels are the first children of planets.
            uint256 last_trixel = getTokenTrixelCount(token) - 1;
            return getTokenTrixel(token, last_trixel);
        } else {
            // We have an invalid token type somehow
            assert(false);
        }
    }

    /**
     * If a token has a possible child for which childIndexOfToken would return the given index, returns that child.
     * Fails otherwise.
     * Index must not be wider than uint16 or it may be truncated.
     */
    function childTokenAtIndex(uint256 token, uint256 index) internal pure returns (uint256) {
        uint256 token_type = getTokenType(token);

        assert(token_type != TOKEN_TYPE_LAND_MAX);

        if (token_type == TOKEN_TYPE_SECTOR) {
            // Set the system field and make it a system token
            return setTokenType(setTokenSystem(token, uint16(index)), TOKEN_TYPE_SYSTEM);
        } else if (token_type == TOKEN_TYPE_SYSTEM) {
            // Set the planet field and make it a planet token
            return setTokenType(setTokenPlanet(token, uint16(index)), TOKEN_TYPE_PLANET);
        } else if (token_type == TOKEN_TYPE_PLANET) {
            // Child could be a land or moon. The land trixels are first as 0-7
            if (index < TOP_TRIXELS) {
                // Make it land and set the first trixel
                return setTokenType(setTokenTrixel(token, 0, uint16(index)), TOKEN_TYPE_LAND_MIN);
            } else {
                // Make it a moon
                return setTokenType(setTokenMoon(token, uint16(index - TOP_TRIXELS)), TOKEN_TYPE_MOON);
            }
        } else if (token_type == TOKEN_TYPE_MOON) {
            // Make it land and set the first trixel
            return setTokenType(setTokenTrixel(token, 0, uint16(index)), TOKEN_TYPE_LAND_MIN);
        } else if (token_type >= TOKEN_TYPE_LAND_MIN && token_type < TOKEN_TYPE_LAND_MAX) {
            // Add another trixel with this value.
            // Its index will be the *count* of existing trixels.
            uint256 next_trixel = getTokenTrixelCount(token);
            return setTokenTrixel(setTokenTrixelCount(token, next_trixel + 1), next_trixel, uint16(index));
        } else {
            // We have an invalid token type somehow
            assert(false);
        }
    }

    /**
     * Not all uint256 values are valid tokens.
     * Returns true if the token represents something that may exist in the Macroverse world.
     * Only does validation of the bitstring representation (i.e. no extraneous set bits).
     * We still need to check in with the generator to validate that the system/planet/moon actually exists.
     */
    function tokenIsCanonical(uint256 token) internal pure returns (bool) {
        
        if (token >> (TOKEN_TRIXEL_SHIFT + TOKEN_TRIXEL_EACH_BITS * getTokenTrixelCount(token)) != 0) {
            // There are bits set above the highest used trixel (for land) or in any trixel (for non-land)
            return false;
        }

        if (tokenIsLand(token)) {
            if (token & (TOKEN_TRIXEL_HIGH_BIT_MASK << TOKEN_TRIXEL_SHIFT) != 0) {
                // A high bit in a trixel other than the first is set
                return false;
            }
        }

        uint256 token_type = getTokenType(token);

        if (token_type == TOKEN_TYPE_MOON) {
            if (getTokenMoon(token) == MOON_NONE) {
                // Not a real moon
                return false;
            }
        } else if (token_type < TOKEN_TYPE_MOON) {
            if (getTokenMoon(token) != 0) {
                // Moon bits need to be clear
                return false;
            }

            if (token_type < TOKEN_TYPE_PLANET) {
                if (getTokenPlanet(token) != 0) {
                    // Planet bits need to be clear
                    return false;
                }

                if (token_type < TOKEN_TYPE_SYSTEM) {
                    if (getTokenSystem(token) != 0) {
                        // System bits need to be clear
                        return false;
                    }
                }
            }
        }

        // We found no problems. Still might not exist, though. Could be an out of range sector or a non-present system, planet or moon.
        return true;
    }

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

    /// Commitments can be committed, revealed, or canceled.
    /// Expired commitments stay committed until canceled.
    enum CommitmentState {
        Committed,
        Revealed,
        Canceled
    }

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
        
        if (getTokenType(token) == TOKEN_TYPE_SECTOR) {
            // No parent exists; we're a tree root.
            return;
        }

        // Find the parent
        uint256 parent = parentOfToken(token);

        // Find what child index we are of the parent
        uint256 child_index = childIndexOfToken(token);
        
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

        if (getTokenType(token) == TOKEN_TYPE_SECTOR) {
            // No parent exists; we're a tree root.
            return;
        }

        // See if we have any children that still exist
        if (childTree[token] == 0) {
            // We are not an existing token ourselves, and we have no existing children.

            // Find the parent
            uint256 parent = parentOfToken(token);

            // Find what child index we are of the parent
            uint256 child_index = childIndexOfToken(token);
            
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
     * Get the lowest-in-the-hierarchy token that exists (is owned or in escrow).
     * Returns a 0-value sentinel if no parent token exists.
     */
    function lowestExistingParent(uint256 token) public view returns (uint256) {
        if (getTokenType(token) == TOKEN_TYPE_SECTOR) {
            // No parent exists, and we can't exist.
            return 0;
        }

        uint256 parent = parentOfToken(token);

        if (_exists(parent)) {
            // We found a token that really exists
            return parent;
        }

        // Otherwise, recurse on the parent
        return lowestExistingParent(parent);
    }

    /**
     * Get the min deposit that will be required to create a claim on a token.
     */
    function getMinDepositToCreate(uint256 token) public view returns (uint256) {
        // Get the token's type
        uint256 token_type = getTokenType(token);

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
            uint256 subdivisions = getTokenTrixelCount(token);
            return minSystemDepositInAtomicUnits.div(30) >> subdivisions;
            // TODO: Look at and balance the exact relationships between planet, moon, and whole-surface claim costs.
        }
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
        require(commitment.creationTime + commitmentMinWait * COMMITMENT_MAX_WAIT_FACTOR > now, "Commitment expired");

        // Make sure the commitment is not too new (min wait is in the past)
        require(commitment.creationTime + commitmentMinWait < now, "Commitment too new");

        // Make sure the token doesn't already exists
        require(!_exists(token), "Token already exists");

        // Validate the token
        require(tokenIsCanonical(token), "Token data mis-packed");
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
        require(!tokenIsLand(token) || childTree[token] == 0, "Cannot claim land with claimed subplots");

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
     * Returns true if direct children of the given token can be claimed by the given claimant.
     * Children of land tokens can never be claimed (the plot must be subdivided).
     * Children of system/planet/moon tokens can only be claimed if the claimer owns them or the owner allows homesteading.
     */
    function childrenClaimable(uint256 token, address claimant) internal view returns (bool) {
        assert(_exists(token));
        return !tokenIsLand(token) && (claimant == ownerOf(token) || tokenConfigs[token].homesteading);
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
        require(!tokenIsLand(token));
        
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
        return (_exists(token) && !tokenIsLand(token) && tokenConfigs[token].homesteading); 
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
        require(getTokenType(parent) != TOKEN_TYPE_LAND_MAX, "Land maximally subdivided");

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
            uint256 child = childTokenAtIndex(parent, i);
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
        uint256 parent = parentOfToken(children[0]);
        for (i = 1; i < CHILDREN_PER_TRIXEL; i++) {
            require(parentOfToken(children[i]) == parent, "Parent not shared");
        }
        
        // Make sure that that parent is land
        require(tokenIsLand(parent));

        // Compute the parent deposit and make sure it will be sufficient
        uint256 parent_deposit = available_deposit.sub(withdraw_deposit);
        require(parent_deposit >= getMinDepositToCreate(parent), "Deposit not sufficient");

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
