pragma solidity ^0.6.10;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./Macroverse.sol";
import "./MacroverseNFTUtils.sol";


/**
 * Contains the terrain generation logic for Macroverse
 *
 * Permission to call methods on this contract is regulated by a configurable
 * AccessControl contract. One such set of terms might be to require that the
 * account initiating a transaction have a certain minimum MRV token balance.
 *
 * The owner of this contract reserves the right to supersede it with a new
 * version, and to modify the terms for accessing this contract, at any time,
 * for any reason, and without notice. This includes the right to indefinitely
 * or permanently suspend or terminate access to this contract for any person,
 * account, or other contract, or for all persons, accounts, or other
 * contracts. The owner also reserves the right to not do any of the above.
 */
contract MacroverseTerrainGenerator is ControlledAccess {
    using RNG for *;
    using MacroverseNFTUtils for *;
    using RealMath for *;
    
    /**@dev
     * How many fractional bits are there?
     */
    int256 constant REAL_FBITS = 40;
    
    /**@dev
     * What's the first non-fractional bit
     */
    int128 constant REAL_ONE = int128(1) << int128(REAL_FBITS);
    
    /**@dev
     * What's the last fractional bit?
     */
    int128 constant REAL_HALF = REAL_ONE >> 1;
    
    // Define the packing format from the NFT utils (again)
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

    /**
     * Deploy a new copy of the MacroverseTerrainGenerator.
     */
    constructor(address accessControlAddress) ControlledAccess(accessControlAddress) public {
        // Nothing to do!
    }
    
    /**
     * Get the height of the given trixel, as represented by a token.
     * Height is returned on the range -1 to 1.
     */
    function getTrixelHeight(uint256 trixelToken, bytes32 worldSeed) external view onlyControlledAccess returns (int128) {
        uint totalDepth = trixelToken.getTokenTrixelCount();
        RNG.RandNode memory node = RNG.RandNode(worldSeed).derive("terrain");
        
        // Accumulate height offsets into here
        int128 realHeight = 0;
        
        // And how much by to scale every added height change by
        int128 realScale = REAL_ONE; 
        
        // Now we use the token as scratch and shift off all the trixel child
        // indexes we care about.
        trixelToken = trixelToken >> TOKEN_TRIXEL_SHIFT;
        for (uint i = 0; i < totalDepth; i++) {
            // Derive the node for this child
            node = node.derive(trixelToken & 0x7);
            // Compute and add the height
            realHeight += (node.getReal() - REAL_HALF).mul(realScale);
            // Shift the next child into place
            trixelToken = trixelToken >> TOKEN_TRIXEL_EACH_BITS;
            // And reduce the scale of the next offset
            realScale = realScale >> 1;
            // We don't need any clamping because even if we have all +1/2 or
            // -1/2, the scaling by 1/2 at each step makes the infinite sum be
            // 1 or -1.
        }
        
        return realHeight;
    }
    
}

// SPDX-License-Identifier: UNLICENSED
