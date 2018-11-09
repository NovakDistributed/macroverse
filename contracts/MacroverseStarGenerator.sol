pragma solidity ^0.4.18;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

/**
 * Represents a Macroverse Generator for a galaxy.
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
contract MacroverseStarGenerator is ControlledAccess {
    // TODO: RNG doesn't get linked against because we can't pass the struct to the library...
    using RNG for *;
    using RealMath for *;
    // No SafeMath or it might confuse RealMath

    // How big is a sector on a side in LY?
    int16 constant SECTOR_SIZE = 25;
    // How far out dowes the sector system extend?
    int16 constant MAX_SECTOR = 10000;
    // How big is the galaxy?
    int16 constant DISK_RADIUS_IN_SECTORS = 6800;
    // How thick is its disk?
    int16 constant DISK_HALFHEIGHT_IN_SECTORS = 40;
    // How big is the central sphere?
    int16 constant CORE_RADIUS_IN_SECTORS = 1000;
    
    // There are kinds of stars.
    // We can add more later; these are from http://www.mit.edu/afs.new/sipb/user/sekullbe/furble/planet.txt
    //                 0           1      2             3           4            5
    enum ObjectClass { Supergiant, Giant, MainSequence, WhiteDwarf, NeutronStar, BlackHole }
    // Actual stars have a spectral type
    //                  0      1      2      3      4      5      6      7
    enum SpectralType { TypeO, TypeB, TypeA, TypeF, TypeG, TypeK, TypeM, NotApplicable }
    // Each type has subtypes 0-9, except O which only has 5-9
    
    // This root RandNode provides the seed for the universe.
    RNG.RandNode root;
    
    /**
     * Deploy a new copy of the Macroverse generator contract. Use the given seed to generate a galaxy, down to the star level.
     * Use the contract at the given address to regulate access.
     */
    function MacroverseStarGenerator(bytes32 baseSeed, address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
        root = RNG.RandNode(baseSeed);
    }
    
    /**
     * Get the density (between 0 and 1 as a fixed-point real88x40) of stars in the given sector. Sector 0,0,0 is centered on the galactic origin.
     * +Y is upwards.
     */
    function getGalaxyDensity(int16 sectorX, int16 sectorY, int16 sectorZ) public view onlyControlledAccess returns (int128 realDensity) {
        // We have a central sphere and a surrounding disk.
        
        // Enforce absolute bounds.
        if (sectorX > MAX_SECTOR) return 0;
        if (sectorY > MAX_SECTOR) return 0;
        if (sectorZ > MAX_SECTOR) return 0;
        if (sectorX < -MAX_SECTOR) return 0;
        if (sectorY < -MAX_SECTOR) return 0;
        if (sectorZ < -MAX_SECTOR) return 0;
        
        if (int(sectorX) * int(sectorX) + int(sectorY) * int(sectorY) + int(sectorZ) * int(sectorZ) < int(CORE_RADIUS_IN_SECTORS) * int(CORE_RADIUS_IN_SECTORS)) {
            // Central sphere
            return RealMath.fraction(9, 10);
        } else if (int(sectorX) * int(sectorX) + int(sectorZ) * int(sectorZ) < int(DISK_RADIUS_IN_SECTORS) * int(DISK_RADIUS_IN_SECTORS) && sectorY < DISK_HALFHEIGHT_IN_SECTORS && sectorY > -DISK_HALFHEIGHT_IN_SECTORS) {
            // Disk
            return RealMath.fraction(1, 2);
        } else {
            // General background object rate
            // Set so that some background sectors do indeed have an object in them.
            return RealMath.fraction(1, 60);
        }
    }
    
    /**
     * Get the number of objects in the sector at the given coordinates.
     */
    function getSectorObjectCount(int16 sectorX, int16 sectorY, int16 sectorZ) public view onlyControlledAccess returns (uint16) {
        // Decide on a base item count
        var sectorNode = root.derive(sectorX).derive(sectorY).derive(sectorZ);
        var maxObjects = sectorNode.derive("count").d(3, 20, 0);
        
        // Multiply by the density function
        var presentObjects = RealMath.toReal(maxObjects).mul(getGalaxyDensity(sectorX, sectorY, sectorZ));
        
        return uint16(RealMath.fromReal(RealMath.round(presentObjects)));
    }
    
    /**
     * Get the seed for an object in a sector.
     */
    function getSectorObjectSeed(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 object) public view onlyControlledAccess returns (bytes32) {
        return root.derive(sectorX).derive(sectorY).derive(sectorZ).derive(uint(object))._hash;
    }
    
    /**
     * Get the class of the star system with the given seed.
     */
    function getObjectClass(bytes32 seed) public view onlyControlledAccess returns (ObjectClass) {
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
    function getObjectSpectralType(bytes32 seed, ObjectClass objectClass) public view onlyControlledAccess returns (SpectralType) {
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
    function getObjectPosition(bytes32 seed) public view onlyControlledAccess returns (int128 realX, int128 realY, int128 realZ) {
        var node = RNG.RandNode(seed).derive("position");
        
        realX = node.derive("x").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
        realY = node.derive("y").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
        realZ = node.derive("z").getRealBetween(RealMath.toReal(0), RealMath.toReal(25));
    }
    
    /**
     * Get the mass of a star, in solar masses as a real, given its seed and class and spectral type.
     */
    function getObjectMass(bytes32 seed, ObjectClass objectClass, SpectralType spectralType) public view onlyControlledAccess returns (int128) {
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
    function getObjectHasPlanets(bytes32 seed, ObjectClass objectClass, SpectralType spectralType) public view onlyControlledAccess returns (bool) {
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
 
