pragma solidity ^0.4.24;

/**
 * This library contains utility functions for creating, parsing, and
 * manipulating Macroverse virtual real estate non-fungible token (NFT)
 * identifiers. The uint256 that identifies a piece of Macroverse virtual real
 * estate includes the type of object that is claimed and its location in the
 * macroverse world, as defined by this library.
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
 * The "trixel" numbers refer to dubdivisions of the surface of a planet or
 * moon, or the area of an asteroid belt or ring. See the documentation for the
 * MacroverseUniversalRegistry for more information on the trixel system.
 *
 * Small functions in the library are internal, because inlining them will take
 * less space than a call.
 *
 * Larger functions are public.
 *
 */
library MacroverseNFTUtils {

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
    function childTokenAtIndex(uint256 token, uint256 index) public pure returns (uint256) {
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
    function tokenIsCanonical(uint256 token) public pure returns (bool) {
        
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

}
