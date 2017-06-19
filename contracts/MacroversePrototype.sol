pragma solidity ^0.4.11;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

/**
 * Represents a prorotype Macroverse Generator for a galaxy.
 */
contract MacroversePrototype is ControlledAccess {
    using RNG for *;
    using RealMath for *;

    // There are kinds of stars.
    // We can add more later; these are from http://www.mit.edu/afs.new/sipb/user/sekullbe/furble/planet.txt
    //                 0           1      2             3           4            5
    enum ObjectClass { Supergiant, Giant, MainSequence, WhiteDwarf, NeutronStar, BlackHole }
    // Actual stars have a spectral type
    //                  0      1      2      3      4      5      6
    enum SpectralType { TypeO, TypeB, TypeA, TypeF, TypeG, TypeK, TypeM }
    // Each type has subtypes 0-9, except O which only has 5-9
    
    // Object Frequencies from  Ross Smith
    // BlackHole: 0.000035
    // NeutronStar: 0.000665
    // WhiteDwarf: 0.0693
    //  TypeB: 0.014 
    //  TypeA: 0.014
    //  TypeG: 0.014
    //  TypeK: 0.0133
    // MainSequence: 0.92
    //  
    // Giant: 0.0099
    // Supergiant: 0.0001
    
    // Object Frequencies from http://www.kcvs.ca/martin/astro/au/unit4/85/chp8_5.htm
    // Giants + Supergiants: ~1.1%
    // Main sequence: ~99%
    
    // New Algorithm
    // Galaxy is divided into 25-ly sectors
    // Galaxy radius is 100k ly = 4k sectors
    // Each sector has a density sampled from the galaxy function.
    // Decide if star should be main sequence, giant, supergiant, or wd/bh
    // Pick a mass appropriate to that type of body (no O,B,A giants, etc.)
    // Apply mass-luminosity relation for appropriate mass range to get luminosity
    // From luminosity calculate effective temperature, and from there spectral class
    
    // This root RandNode provides the seed for the universe.
    RNG.RandNode root;
    
    /**
     * Deploy a new copy of the Macroverse prototype contract. Use the given seed to generate the star system.
     * Use the contract at the given address to regulate access.
     */
    function MacroversePrototype(bytes32 baseSeed, address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) {
        root = RNG.RandNode(baseSeed);
    }
    
    /**
     * Get the density (between 0 and 1 as a fixed-point real88x40) of stars in the given sector. Sector 0,0,0 is centered on the galactic origin.
     * +Y is upwards.
     */
    function getGalaxyDensity(int sectorX, int sectorY, int sectorZ) constant onlyControlledAccess returns (int128 realDensity) {
        // For the prototype, we have a central sphere and a surrounding disk.
        
        // Enforce absolute bounds.
        if (sectorX > 5000) return 0;
        if (sectorY > 5000) return 0;
        if (sectorZ > 5000) return 0;
        if (sectorX < -5000) return 0;
        if (sectorY < -5000) return 0;
        if (sectorZ < -5000) return 0;
        
        if (sectorX * sectorX + sectorY * sectorY + sectorZ * sectorZ < 500 ** 2) {
            // Central sphere
            return RealMath.fraction(9, 10);
        } else if (sectorX * sectorX + sectorZ * sectorZ < 4000 ** 2 && sectorY < 200 && sectorY > -200) {
            // Disk
            return RealMath.fraction(1, 2);
        } else {
            // General background object rate
            return RealMath.fraction(1, 100);
        }
    }

}
 