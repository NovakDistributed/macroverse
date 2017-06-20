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
    //                  0      1      2      3      4      5      6      7
    enum SpectralType { TypeO, TypeB, TypeA, TypeF, TypeG, TypeK, TypeM, NotApplicable }
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
    // Pick a spectral class and mass
    // Apply mass-luminosity relation for appropriate mass range to get luminosity
    
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
    
    /**
     * Get the number of objects in the sector at the given coordinates.
     */
    function getSectorObjectCount(int sectorX, int sectorY, int sectorZ) constant onlyControlledAccess returns (uint) {
        // Decide on a base item count
        var sectorNode = root.derive(sectorX).derive(sectorY).derive(sectorZ);
        var maxObjects = sectorNode.derive("count").d(3, 20, 0);
        
        // Multiply by the density function
        var presentObjects = RealMath.toReal(maxObjects).mul(getGalaxyDensity(sectorX, sectorY, sectorZ));
        
        return uint(RealMath.fromReal(presentObjects));
    }
    
    /**
     * Get the seed for an object in a sector.
     */
    function getSectorObjectSeed(int sectorX, int sectorY, int sectorZ, uint object) constant onlyControlledAccess returns (bytes32) {
        return root.derive(sectorX).derive(sectorY).derive(sectorZ).derive(object)._hash;
    }
    
    /**
     * Get the class of the star system with the given seed.
     */
    function getObjectClass(bytes32 seed) constant onlyControlledAccess returns (ObjectClass) {
        // Make a node for rolling for the class.
        var node = RNG.RandNode(seed).derive("class");
        // Roll an impractical d10,000
        var roll = node.getIntBetween(1, 10000);
        
        if (roll == 1) {
            // Should be a black hole
            return ObjectClass.BlackHole;
        } else if (roll <= 3) {
            // Should be a neutron star
            return ObjectClass.NeutronStar;
        } else if (roll <= 700) {
            // Should be a white dwarf
            return ObjectClass.WhiteDwarf;
        } else if (roll <= 9900) {
            // Most things are main sequence
            return ObjectClass.MainSequence;
        } else if (roll <= 9990) {
            return ObjectClass.Giant;
        } else {
            return ObjectClass.Supergiant;
        }
    }
    
    /**
     * Get the spectral type for an object with the given seed of the given class.
     */
    function getObjectSpectralType(bytes32 seed, ObjectClass objectClass) constant onlyControlledAccess returns (SpectralType) {
        var node = RNG.RandNode(seed).derive("type");
        var roll = node.getIntBetween(1, 10000000); // Even more implausible dice

        if (objectClass == ObjectClass.MainSequence) {
            if (roll <= 3) {
                return SpectralType.TypeO;
            } else if (roll <= 13003) {
                return SpectralType.TypeB;
            } else if (roll <= 73003) {
                return SpectralType.TypeA;
            } else if (roll <= 373003) {
                return SpectralType.TypeF;
            } else if (roll <= 1133003) {
                return SpectralType.TypeG;
            } else if (roll <= 2343003) {
                return SpectralType.TypeK;
            } else {
                return SpectralType.TypeM;
            }
        } else if (objectClass == ObjectClass.Giant) {
            if (roll <= 500000) {
                return SpectralType.TypeF;
            } else if (roll <= 1000000) {
                return SpectralType.TypeG;
            } else if (roll <= 5500000) {
                return SpectralType.TypeK;
            } else {
                return SpectralType.TypeM;
            }
        } else if (objectClass == ObjectClass.Supergiant) {
            if (roll <= 1000000) {
                return SpectralType.TypeB;
            } else if (roll <= 2000000) {
                return SpectralType.TypeA;
            } else if (roll <= 4000000) {
                return SpectralType.TypeF;
            } else if (roll <= 6000000) {
                return SpectralType.TypeG;
            } else if (roll <= 8000000) {
                return SpectralType.TypeK;
            } else {
                return SpectralType.TypeM;
            }
        } else {
            // TODO: No spectral class for anyone else.
            return SpectralType.NotApplicable;
        }
        
    }
    
    /**
     * Get the position of a star within its sector, as reals from 0 to 25.
     * Note that stars may end up implausibly close together. Such is life in the Macroverse.
     */
    function getObjectPosition(bytes32 seed) constant onlyControlledAccess returns (int128 realX, int128 realY, int128 realZ) {
        var node = RNG.RandNode(seed).derive("position");
        
        realX = node.derive("x").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
        realY = node.derive("y").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
        realZ = node.derive("z").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
    }
    
    /**
     * Get the mass of a star, in solar masses as a real, given its seed and class and spectral type.
     */
    function getObjectMass(bytes32 seed, ObjectClass objectClass, SpectralType spectralType) constant onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("mass");
         
        if (objectClass == ObjectClass.BlackHole) {
            return node.getRealBetween(RealMath.toReal(5), RealMath.toReal(50));
        } else if (objectClass == ObjectClass.NeutronStar) {
            return node.getRealBetween(RealMath.fraction(11, 10), RealMath.toReal(2));
        } else if (objectClass == ObjectClass.WhiteDwarf) {
            return node.getRealBetween(RealMath.fraction(3, 10), RealMath.fraction(11, 10));
        } else if (objectClass == ObjectClass.MainSequence) {
            if (spectralType == SpectralType.TypeO) {
                return node.getRealBetween(RealMath.toReal(16), RealMath.toReal(40));
            } else if (spectralType == SpectralType.TypeB) {
                return node.getRealBetween(RealMath.fraction(21, 10), RealMath.toReal(16));
            } else if (spectralType == SpectralType.TypeA) {
                return node.getRealBetween(RealMath.fraction(14, 10), RealMath.fraction(21, 10));
            } else if (spectralType == SpectralType.TypeF) {
                return node.getRealBetween(RealMath.fraction(104, 100), RealMath.fraction(14, 10));
            } else if (spectralType == SpectralType.TypeG) {
                return node.getRealBetween(RealMath.fraction(80, 100), RealMath.fraction(104, 100));
            } else if (spectralType == SpectralType.TypeK) {
                return node.getRealBetween(RealMath.fraction(45, 100), RealMath.fraction(80, 100));
            } else if (spectralType == SpectralType.TypeM) {
                return node.getRealBetween(RealMath.fraction(8, 100), RealMath.fraction(45, 100));
            }
        } else if (objectClass == ObjectClass.Giant) {
            // Just make it really big
            return node.getRealBetween(RealMath.toReal(40), RealMath.toReal(50));
        } else if (objectClass == ObjectClass.Supergiant) {
            // Just make it really, really big
            return node.getRealBetween(RealMath.toReal(50), RealMath.toReal(70));
        }
    }
    
    /**
     * Determine if the given star has any orbiting planets or not.
     */
    function getObjectHasPlanets(bytes32 seed, ObjectClass objectClass, SpectralType spectralType) constant onlyControlledAccess returns (bool) {
        var node = RNG.RandNode(seed).derive("hasplanets");
        var roll = node.getIntBetween(1, 1000);

        if (objectClass == ObjectClass.MainSequence) {
            if (spectralType == SpectralType.TypeO || spectralType == SpectralType.TypeB) {
                return (roll <= 1);
            } else if (spectralType == SpectralType.TypeA) {
                return (roll <= 500);
            } else if (spectralType == SpectralType.TypeF || spectralType == SpectralType.TypeG || spectralType == SpectralType.TypeK) {
                return (roll <= 990);
            } else if (spectralType == SpectralType.TypeM) {
                return (roll <= 634);
            }
        } else if (objectClass == ObjectClass.Giant) {
            return (roll <= 90);
        } else if (objectClass == ObjectClass.Supergiant) {
            return (roll <= 50);
        } else {
           // Black hole, neutron star, or white dwarf
           return (roll <= 70);
        }
    }
    

}
 