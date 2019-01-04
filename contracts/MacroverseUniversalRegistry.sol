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
 * At the astronomical level (stars, planets, moons), deed tokens can be issued
 * for the children of things already claimed, if the lowest owned parent token
 * has homesteading enabled.  At the land level, only one deed token can cover
 * a given point at a given time, but plots can be subdivided and merged
 * according to the trixel structure.
 *
 * Internally, bookkeeping data is kept to allow the tree of all issued tokens
 * to be traversed. All issued tokens exist in the tree, as well as the
 * internal nodes of the token hierarchy necessary to connect them. The
 * presence of child nodes in the tree is tracked using a bitmap for each node.
 *
 * Acquiring ownership of something is a three-phase process.
 *
 * First, you have to commit: publish a hash of the token ID you want to claim
 * and a salt, and put up a deposit, to establish a priority date. Commitments
 * eventually expire, after which all you can do with them is cancel them and
 * get your deposit back.
 *
 * The next step is to reveal your commitment. You can do this as soon as your
 * commitment has been mined. You publish the ID of the token you are trying to
 * claim, and the salt you used to generate your commitment hash. At this
 * point, if the token you are trying to claim is unclaimed and legal to claim,
 * it will be created and placed into escrow (owned by the registry contract).
 * If the token already exists and is still in escrow, and you have an earlier
 * commitment than the person who it is currently in escrow for, you will
 * become its new pending owner.
 *
 * Finally, once the mandatory escrow period has elapsed, and all commitments
 * before yours are expired without any of them having taken the token you were
 * trying to claim, you can close escrow and actually take custody of the
 * token.
 *
 * Alternately, if the token was taken by another claimant with an earlier
 * claim while in escrow, all you can do is cancel your commitment and take
 * back your deposit.
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

    // We keep a bit mask of the high bits of all but the least specific trixel.
    // None of these may be set
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
            assert(value <= 7);
        } else {
            assert(value <= 3);
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
    // Contract state
    //////////////


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
        require(tokenAddress.transferFrom(msg.sender, this, deposit), "Deposit not approved");

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

        if (tokenIsLand(token)) {
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
     * Returns true if children of the given token can be claimed by the given claimant.
     * Children of land tokens can never be claimed (the plot must be subdivided).
     * Children of system/planet/moon tokens can only be claimed if:
     * 1. No parent is owned
     * 2. Claimant is the owner of the lowest owned parent
     * 3. The owner of the lowest owned parent has set it to allow subclaims/homesteading
     */
    function childrenClaimable(uint256 token, address claimant) internal view returns (bool) {
        // TODO: implement parent search
        // TODO: implement homesteading
        return !tokenIsLand(token) && (!_exists(token) || claimant == ownerOf(token));
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
