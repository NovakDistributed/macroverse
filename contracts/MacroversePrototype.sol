pragma solidity ^0.4.11;

import "./RNG.sol";

/**
 * Represents a prorotype Macroverse Generator, for a single star system according to an
 * adaptation of <http://www.mit.edu/afs.new/sipb/user/sekullbe/furble/planet.txt>.
 */
contract MacroversePrototype {
    using RNG for *;

    // There are kinds of stars
    //                 0           1      2             3           4            5
    enum ObjectClass { Supergiant, Giant, MainSequence, WhiteDwarf, NeutronStar, BlackHole }
    // Actual stars have a spectral type
    //                  0      1      2      3      4      5      6
    enum SpectralType { TypeO, TypeB, TypeA, TypeF, TypeG, TypeK, TypeM }
    // Each type has subtypes 0-9, except O which only has 5-9
    

    RNG.RandNode root;
    
    /**
     * Deploy a new copy of the Macroverse prototype contract. Use the given seed to generate the star system.
     */
    function MacroversePrototype(bytes32 base_seed) {
        root = RNG.RandNode(base_seed);
    }
    
    /**
     * What star type is the star?
     */
    function getStarType() constant returns (ObjectClass class, SpectralType spectral_type, uint8 subtype) {
        // Roll 3 distinct d100s
        var roll1 = root.derive("star1").d(1, 100, 0);
        var roll2 = root.derive("star2").d(1, 100, 0);
        var roll3 = root.derive("star3").d(1, 100, 0);
        
        if (roll1 == 1) {
            // Supergiant or giant
            if (roll2 == 1) {
                // Supergiant
                class = ObjectClass.Supergiant;
                if (roll3 <= 10) {
                    spectral_type = SpectralType.TypeB;
                } else if (roll3 <= 20) {
                    spectral_type = SpectralType.TypeA;
                } else if (roll3 <= 40) {
                    spectral_type = SpectralType.TypeF;
                } else if (roll3 <= 60) {
                    spectral_type = SpectralType.TypeG;
                } else if (roll3 <= 80) {
                    spectral_type = SpectralType.TypeK;
                } else {
                    spectral_type = SpectralType.TypeM;
                }
            } else {
                // Normal giant
                class = ObjectClass.Giant;
                if (roll2 <= 5) {
                    spectral_type = SpectralType.TypeF;
                } else if (roll2 <= 10) {
                    spectral_type = SpectralType.TypeG;
                } else if (roll2 <= 55) {
                    spectral_type = SpectralType.TypeK;
                } else {
                    spectral_type = SpectralType.TypeM;
                }
            }
            // Assign a subtype; no O is possible here so all are 1-10.
            subtype = uint8(root.derive("subtype").d(1, 10, -1));
        } else if (roll1 <= 93) {
            // Main sequence
            class = ObjectClass.MainSequence;
            if (roll2 == 1) {
                // O or B
                if (roll3 == 1) {
                    // O, very rare
                    spectral_type = SpectralType.TypeO;
                    // Subtypes are 5-9
                    subtype = uint8(root.derive("subtype").d(1, 5, 4));
                } else {
                    // B, less rare
                    spectral_type = SpectralType.TypeB;
                    subtype = uint8(root.derive("subtype").d(1, 10, -1));
                }
            } else {
                if (roll2 <= 3) {
                    // A
                    spectral_type = SpectralType.TypeA;
                } else if (roll2 <= 7) {
                    spectral_type = SpectralType.TypeF;
                } else if (roll2 <= 15) {
                    spectral_type = SpectralType.TypeG;
                } else if (roll2 <= 31) {
                    spectral_type = SpectralType.TypeK;
                } else {
                    spectral_type = SpectralType.TypeM;
                }
                subtype = uint8(root.derive("subtype").d(1, 10, -1));
            }
        } else {
            if (roll2 <= 99) {
                // White dwarf, no subtype
                class = ObjectClass.WhiteDwarf;
                if (roll2 <= 20) {
                    spectral_type = SpectralType.TypeB;
                } else if (roll2 <= 40) {
                    spectral_type = SpectralType.TypeA;
                } else if (roll2 <= 60) {
                    spectral_type = SpectralType.TypeF;
                } else if (roll2 <= 80) {
                    spectral_type = SpectralType.TypeG;
                } else {
                    spectral_type = SpectralType.TypeK;
                }
            } else {
                // Neutron star or black hole, no type or subtype
                if (roll3 <= 95) {
                    class = ObjectClass.NeutronStar;
                } else {
                    // Black hole!
                    class = ObjectClass.BlackHole;
                }
            }
        }
    }
    
    /**
     * How many planets does this system have?
     */
    function getPlanetCount() constant returns (uint) {
    }
    

}
 