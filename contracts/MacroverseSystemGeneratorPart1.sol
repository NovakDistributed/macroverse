pragma solidity ^0.6.10;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./Macroverse.sol";


/**
 * Contains a portion of the MacroverseStstemGenerator implementation code.
 * The contract is split up due to contract size limitations.
 * We can't do access control here sadly.
 */
library MacroverseSystemGeneratorPart1 {
    // TODO: RNG doesn't get linked against because we can't pass the struct to the library...
    using RNG for *;
    using RealMath for *;
    // No SafeMath or it might confuse RealMath

    /**@dev
     * It is useful to have Pi around.
     * We can't pull it in from the library.
     */
    int128 constant REAL_PI = 3454217652358;

    /**@dev
     * Also perpare pi/2
     */
    int128 constant REAL_HALF_PI = REAL_PI >> 1;

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
    
    /**@dev
     * What's two? Two is pretty useful.
     */
    int128 constant REAL_TWO = REAL_ONE << int128(1);

    /**@dev
     * And zero
     */
    int128 constant REAL_ZERO = 0;

    /**
     * Get the seed for a planet or moon from the seed for its parent (star or planet) and its child number.
     */
    function getWorldSeed(bytes32 parentSeed, uint16 childNumber) public pure returns (bytes32) {
        return RNG.RandNode(parentSeed).derive(uint(childNumber))._hash;
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     * Takes the *planet*'s seed, its number, and the total planets in the system.
     */
    function getPlanetClass(bytes32 seed, uint16 planetNumber, uint16 totalPlanets) public pure returns (Macroverse.WorldClass) {
        // TODO: do something based on metallicity?
        RNG.RandNode memory node = RNG.RandNode(seed).derive("class");
        
        int88 roll = node.getIntBetween(0, 100);
        
        // Inner planets should be more planet-y, ideally smaller
        // Asteroid belts shouldn't be first that often
        
        if (planetNumber == 0 && totalPlanets != 1) {
            // Innermost planet of a multi-planet system
            // No asteroid belts allowed!
            // Also avoid too much watery stuff here because we don't want to deal with the water having been supposed to boil off.
            if (roll < 69) {
                return Macroverse.WorldClass.Lunar;
            } else if (roll < 70) {
                return Macroverse.WorldClass.Europan;
            } else if (roll < 79) {
                return Macroverse.WorldClass.Terrestrial;
            } else if (roll < 80) {
                return Macroverse.WorldClass.Panthalassic;
            } else if (roll < 90) {
                return Macroverse.WorldClass.Neptunian;
            } else {
                return Macroverse.WorldClass.Jovian;
            }
        } else if (planetNumber < totalPlanets / 2) {
            // Inner system
            if (roll < 15) {
                return Macroverse.WorldClass.Lunar;
            } else if (roll < 20) {
                return Macroverse.WorldClass.Europan;
            } else if (roll < 35) {
                return Macroverse.WorldClass.Terrestrial;
            } else if (roll < 40) {
                return Macroverse.WorldClass.Panthalassic;
            } else if (roll < 70) {
                return Macroverse.WorldClass.Neptunian;
            } else if (roll < 80) {
                return Macroverse.WorldClass.Jovian;
            } else {
                return Macroverse.WorldClass.AsteroidBelt;
            }
        } else {
            // Outer system
            if (roll < 5) {
                return Macroverse.WorldClass.Lunar;
            } else if (roll < 20) {
                return Macroverse.WorldClass.Europan;
            } else if (roll < 22) {
                return Macroverse.WorldClass.Terrestrial;
            } else if (roll < 30) {
                return Macroverse.WorldClass.Panthalassic;
            } else if (roll < 60) {
                return Macroverse.WorldClass.Neptunian;
            } else if (roll < 90) {
                return Macroverse.WorldClass.Jovian;
            } else {
                return Macroverse.WorldClass.AsteroidBelt;
            }
        }
    }
    
    /**
     * Decide what the mass of the planet or moon is. We can't do even the mass of
     * Jupiter in the ~88 bits we have in a real (should we have used int256 as
     * the backing type?) so we work in Earth masses.
     *
     * Also produces the masses for moons.
     */
    function getWorldMass(bytes32 seed, Macroverse.WorldClass class) public pure returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("mass");
        
        if (class == Macroverse.WorldClass.Asteroidal) {
            // For tiny bodies like this we work in nano-earths
            return node.getRealBetween(RealMath.fraction(1, 1000000000), RealMath.fraction(10, 1000000000));
        } else if (class == Macroverse.WorldClass.Cometary) {
            return node.getRealBetween(RealMath.fraction(1, 1000000000), RealMath.fraction(10, 1000000000));
        } else if (class == Macroverse.WorldClass.Lunar) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(9, 100));
        } else if (class == Macroverse.WorldClass.Europan) {
            return node.getRealBetween(RealMath.fraction(8, 1000), RealMath.fraction(80, 1000));
        } else if (class == Macroverse.WorldClass.Terrestrial) {
            return node.getRealBetween(RealMath.fraction(10, 100), RealMath.toReal(9));
        } else if (class == Macroverse.WorldClass.Panthalassic) {
            return node.getRealBetween(RealMath.fraction(80, 1000), RealMath.toReal(9));
        } else if (class == Macroverse.WorldClass.Neptunian) {
            return node.getRealBetween(RealMath.toReal(7), RealMath.toReal(20));
        } else if (class == Macroverse.WorldClass.Jovian) {
            return node.getRealBetween(RealMath.toReal(50), RealMath.toReal(400));
        } else if (class == Macroverse.WorldClass.AsteroidBelt) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(20, 100));
        } else if (class == Macroverse.WorldClass.Ring) {
            // Saturn's rings are maybe about 5-15 micro-earths
            return node.getRealBetween(RealMath.fraction(1, 1000000), RealMath.fraction(20, 1000000));
        } else {
            // Not real!
            revert();
        }
    }
    
    // Define the orbit shape

    /**
     * Given the parent star's habitable zone bounds, the planet seed, the planet class
     * to be generated, and the "clearance" radius around the previous planet
     * in meters, produces orbit statistics (periapsis, apoapsis, and
     * clearance) in meters.
     *
     * The first planet uses a previous clearance of 0.
     *
     * TODO: realOuterRadius from the habitable zone never gets used. We should remove it.
     */
    function getPlanetOrbitDimensions(int128 realInnerRadius, int128 realOuterRadius, bytes32 seed, Macroverse.WorldClass class, int128 realPrevClearance)
        public pure returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        // We scale all the random generation around the habitable zone distance.

        // Make the planet RNG node to use for all the computations
        RNG.RandNode memory node = RNG.RandNode(seed);
        
        // Compute the statistics with their own functions
        realPeriapsis = getPlanetPeriapsis(realInnerRadius, realOuterRadius, node, class, realPrevClearance);
        realApoapsis = getPlanetApoapsis(realInnerRadius, realOuterRadius, node, class, realPeriapsis);
        realClearance = getPlanetClearance(realInnerRadius, realOuterRadius, node, class, realApoapsis);
    }

    /**
     * Decide what the planet's orbit's periapsis is, in meters.
     * This is the first statistic about the orbit to be generated.
     *
     * For the first planet, realPrevClearance is 0. For others, it is the
     * clearance (i.e. distance from star that the planet has cleared out) of
     * the previous planet.
     */
    function getPlanetPeriapsis(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode memory planetNode, Macroverse.WorldClass class, int128 realPrevClearance)
        internal pure returns (int128) {
        
        // We're going to sample 2 values and take the minimum, to get a nicer distribution than uniform.
        // We really kind of want a log scale but that's expensive.
        RNG.RandNode memory node1 = planetNode.derive("periapsis");
        RNG.RandNode memory node2 = planetNode.derive("periapsis2");
        
        // Define minimum and maximum periapsis distance above previous planet's
        // cleared band. Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == Macroverse.WorldClass.Lunar || class == Macroverse.WorldClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == Macroverse.WorldClass.Terrestrial || class == Macroverse.WorldClass.Panthalassic) {
            minimum = 20;
            maximum = 70;
        } else if (class == Macroverse.WorldClass.Neptunian) {
            minimum = 50;
            maximum = 1000;
        } else if (class == Macroverse.WorldClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == Macroverse.WorldClass.AsteroidBelt) {
            minimum = 20;
            maximum = 500;
        } else {
            // Not real!
            revert();
        }
        
        int128 realSeparation1 = node1.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realSeparation2 = node2.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realSeparation = realSeparation1 < realSeparation2 ? realSeparation1 : realSeparation2;
        return realPrevClearance + RealMath.mul(realSeparation, realInnerRadius).div(RealMath.toReal(100)); 
    }
    
    /**
     * Decide what the planet's orbit's apoapsis is, in meters.
     * This is the second statistic about the orbit to be generated.
     */
    function getPlanetApoapsis(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode memory planetNode, Macroverse.WorldClass class, int128 realPeriapsis)
        internal pure returns (int128) {
        
        RNG.RandNode memory node1 = planetNode.derive("apoapsis");
        RNG.RandNode memory node2 = planetNode.derive("apoapsis2");
        
        // Define minimum and maximum apoapsis distance above planet's periapsis.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == Macroverse.WorldClass.Lunar || class == Macroverse.WorldClass.Europan) {
            minimum = 0;
            maximum = 6;
        } else if (class == Macroverse.WorldClass.Terrestrial || class == Macroverse.WorldClass.Panthalassic) {
            minimum = 0;
            maximum = 10;
        } else if (class == Macroverse.WorldClass.Neptunian) {
            minimum = 20;
            maximum = 500;
        } else if (class == Macroverse.WorldClass.Jovian) {
            minimum = 10;
            maximum = 200;
        } else if (class == Macroverse.WorldClass.AsteroidBelt) {
            minimum = 10;
            maximum = 100;
        } else {
            // Not real!
            revert();
        }
        
        int128 realWidth1 = node1.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realWidth2 = node2.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realWidth = realWidth1 < realWidth2 ? realWidth1 : realWidth2; 
        return realPeriapsis + RealMath.mul(realWidth, realInnerRadius).div(RealMath.toReal(100)); 
    }
    
    /**
     * Decide how far out the cleared band after the planet's orbit is.
     */
    function getPlanetClearance(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode memory planetNode, Macroverse.WorldClass class, int128 realApoapsis)
        internal pure returns (int128) {
        
        RNG.RandNode memory node1 = planetNode.derive("cleared");
        RNG.RandNode memory node2 = planetNode.derive("cleared2");
        
        // Define minimum and maximum clearance.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == Macroverse.WorldClass.Lunar || class == Macroverse.WorldClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == Macroverse.WorldClass.Terrestrial || class == Macroverse.WorldClass.Panthalassic) {
            minimum = 40;
            maximum = 70;
        } else if (class == Macroverse.WorldClass.Neptunian) {
            minimum = 300;
            maximum = 700;
        } else if (class == Macroverse.WorldClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == Macroverse.WorldClass.AsteroidBelt) {
            minimum = 20;
            maximum = 500;
        } else {
            // Not real!
            revert();
        }
        
        int128 realSeparation1 = node1.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realSeparation2 = node2.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        int128 realSeparation = realSeparation1 < realSeparation2 ? realSeparation1 : realSeparation2;
        return realApoapsis + RealMath.mul(realSeparation, realInnerRadius).div(RealMath.toReal(100)); 
    }
}

// SPDX-License-Identifier: UNLICENSED
