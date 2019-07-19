pragma solidity ^0.4.24;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

/**
 * Represents a Macroverse generator for planetary systems around stars and
 * other stellar objects.
 *
 * Because of contract size limitations, some code in this contract is shared
 * between planets and moons, while some code is planet-specific. Moon-specific
 * code lives in the MacroverseMoonGenerator.
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
contract MacroverseSystemGenerator is ControlledAccess {
    // TODO: RNG doesn't get linked against because we can't pass the struct to the library...
    using RNG for *;
    using RealMath for *;
    // No SafeMath or it might confuse RealMath

    /**
     * It is useful to have Pi around.
     * We can't pull it in from the library.
     */
    int128 constant REAL_PI = 3454217652358;

    /**
     * Also perpare pi/2
     */
    int128 constant REAL_HALF_PI = REAL_PI >> 1;

    /**
     * How many fractional bits are there?
     */
    int256 constant REAL_FBITS = 40;
    
    /**
     * What's the first non-fractional bit
     */
    int128 constant REAL_ONE = int128(1) << REAL_FBITS;
    
    /**
     * What's the last fractional bit?
     */
    int128 constant REAL_HALF = REAL_ONE >> 1;
    
    /**
     * What's two? Two is pretty useful.
     */
    int128 constant REAL_TWO = REAL_ONE << 1;

    /**
     * And zero
     */
    int128 constant REAL_ZERO = 0;

    /**
     * Define different types of planet or moon.
     * 
     * There are two main progressions:
     * Asteroidal, Lunar, Terrestrial, Jovian are rocky things.
     * Cometary, Europan, Panthalassic, Neptunian are icy/watery things, depending on temperature.
     * The last thing in each series is the gas/ice giant.
     *
     * Asteroidal and Cometary are only valid for moons; we don't track such tiny bodies at system scale.
     *
     * We also have rings and asteroid belts. Rings can only be around planets, and we fake the Roche limit math we really should do.
     * 
     */
    enum WorldClass {Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt}

    /**
     * Deploy a new copy of the MacroverseSystemGenerator.
     */
    constructor(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
        // Nothing to do!
    }
    
    /**
     * Get the seed for a planet or moon from the seed for its parent (star or planet) and its child number.
     */
    function getWorldSeed(bytes32 parentSeed, uint16 childNumber) public view onlyControlledAccess returns (bytes32) {
        return RNG.RandNode(parentSeed).derive(uint(childNumber))._hash;
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     * Takes the *planet*'s seed, its number, and the total planets in the system.
     */
    function getPlanetClass(bytes32 seed, uint16 planetNumber, uint16 totalPlanets) public view onlyControlledAccess returns (WorldClass) {
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
                return WorldClass.Lunar;
            } else if (roll < 70) {
                return WorldClass.Europan;
            } else if (roll < 79) {
                return WorldClass.Terrestrial;
            } else if (roll < 80) {
                return WorldClass.Panthalassic;
            } else if (roll < 90) {
                return WorldClass.Neptunian;
            } else {
                return WorldClass.Jovian;
            }
        } else if (planetNumber < totalPlanets / 2) {
            // Inner system
            if (roll < 15) {
                return WorldClass.Lunar;
            } else if (roll < 20) {
                return WorldClass.Europan;
            } else if (roll < 35) {
                return WorldClass.Terrestrial;
            } else if (roll < 40) {
                return WorldClass.Panthalassic;
            } else if (roll < 70) {
                return WorldClass.Neptunian;
            } else if (roll < 80) {
                return WorldClass.Jovian;
            } else {
                return WorldClass.AsteroidBelt;
            }
        } else {
            // Outer system
            if (roll < 5) {
                return WorldClass.Lunar;
            } else if (roll < 20) {
                return WorldClass.Europan;
            } else if (roll < 22) {
                return WorldClass.Terrestrial;
            } else if (roll < 30) {
                return WorldClass.Panthalassic;
            } else if (roll < 60) {
                return WorldClass.Neptunian;
            } else if (roll < 90) {
                return WorldClass.Jovian;
            } else {
                return WorldClass.AsteroidBelt;
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
    function getWorldMass(bytes32 seed, WorldClass class) public view onlyControlledAccess returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("mass");
        
        if (class == WorldClass.Asteroidal) {
            // For tiny bodies like this we work in nano-earths
            return node.getRealBetween(RealMath.fraction(1, 1000000000), RealMath.fraction(10, 1000000000));
        } else if (class == WorldClass.Cometary) {
            return node.getRealBetween(RealMath.fraction(1, 1000000000), RealMath.fraction(10, 1000000000));
        } else if (class == WorldClass.Lunar) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(9, 100));
        } else if (class == WorldClass.Europan) {
            return node.getRealBetween(RealMath.fraction(8, 1000), RealMath.fraction(80, 1000));
        } else if (class == WorldClass.Terrestrial) {
            return node.getRealBetween(RealMath.fraction(10, 100), RealMath.toReal(9));
        } else if (class == WorldClass.Panthalassic) {
            return node.getRealBetween(RealMath.fraction(80, 1000), RealMath.toReal(9));
        } else if (class == WorldClass.Neptunian) {
            return node.getRealBetween(RealMath.toReal(7), RealMath.toReal(20));
        } else if (class == WorldClass.Jovian) {
            return node.getRealBetween(RealMath.toReal(50), RealMath.toReal(400));
        } else if (class == WorldClass.AsteroidBelt) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(20, 100));
        } else if (class == WorldClass.Ring) {
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
    function getPlanetOrbitDimensions(int128 realInnerRadius, int128 realOuterRadius, bytes32 seed, WorldClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

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
    function getPlanetPeriapsis(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode planetNode, WorldClass class, int128 realPrevClearance)
        internal pure returns (int128) {
        
        // We're going to sample 2 values and take the minimum, to get a nicer distribution than uniform.
        // We really kind of want a log scale but that's expensive.
        RNG.RandNode memory node1 = planetNode.derive("periapsis");
        RNG.RandNode memory node2 = planetNode.derive("periapsis2");
        
        // Define minimum and maximum periapsis distance above previous planet's
        // cleared band. Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == WorldClass.Lunar || class == WorldClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == WorldClass.Terrestrial || class == WorldClass.Panthalassic) {
            minimum = 20;
            maximum = 70;
        } else if (class == WorldClass.Neptunian) {
            minimum = 50;
            maximum = 1000;
        } else if (class == WorldClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == WorldClass.AsteroidBelt) {
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
    function getPlanetApoapsis(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode planetNode, WorldClass class, int128 realPeriapsis)
        internal pure returns (int128) {
        
        RNG.RandNode memory node1 = planetNode.derive("apoapsis");
        RNG.RandNode memory node2 = planetNode.derive("apoapsis2");
        
        // Define minimum and maximum apoapsis distance above planet's periapsis.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == WorldClass.Lunar || class == WorldClass.Europan) {
            minimum = 0;
            maximum = 6;
        } else if (class == WorldClass.Terrestrial || class == WorldClass.Panthalassic) {
            minimum = 0;
            maximum = 10;
        } else if (class == WorldClass.Neptunian) {
            minimum = 20;
            maximum = 500;
        } else if (class == WorldClass.Jovian) {
            minimum = 10;
            maximum = 200;
        } else if (class == WorldClass.AsteroidBelt) {
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
    function getPlanetClearance(int128 realInnerRadius, int128 /* realOuterRadius */, RNG.RandNode planetNode, WorldClass class, int128 realApoapsis)
        internal pure returns (int128) {
        
        RNG.RandNode memory node1 = planetNode.derive("cleared");
        RNG.RandNode memory node2 = planetNode.derive("cleared2");
        
        // Define minimum and maximum clearance.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == WorldClass.Lunar || class == WorldClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == WorldClass.Terrestrial || class == WorldClass.Panthalassic) {
            minimum = 40;
            maximum = 70;
        } else if (class == WorldClass.Neptunian) {
            minimum = 300;
            maximum = 700;
        } else if (class == WorldClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == WorldClass.AsteroidBelt) {
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
    
    /**
     * Convert from periapsis and apoapsis to semimajor axis and eccentricity.
     */
    function convertOrbitShape(int128 realPeriapsis, int128 realApoapsis) public view onlyControlledAccess returns (int128 realSemimajor, int128 realEccentricity) {
        // Semimajor axis is average of apoapsis and periapsis
        realSemimajor = RealMath.div(realApoapsis + realPeriapsis, RealMath.toReal(2));
        
        // Eccentricity is ratio of difference and sum
        realEccentricity = RealMath.div(realApoapsis - realPeriapsis, realApoapsis + realPeriapsis);
    }
    
    // Define the orbital plane
    
    /**
     * Get the longitude of the ascending node for a planet or moon. For
     * planets, this is the angle from system +X to ascending node. For
     * moons, we use system +X transformed into the planet's equatorial plane
     * by the equatorial plane/rotation axis angles.
     */ 
    function getWorldLan(bytes32 seed) public view onlyControlledAccess returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("LAN");
        // Angles should be uniform from 0 to 2 PI
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }
    
    /**
     * Get the inclination (angle from system XZ plane to orbital plane at the ascending node) for a planet.
     * For a moon, this is done in the moon generator instead.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getPlanetInclination(bytes32 seed, WorldClass class) public view onlyControlledAccess returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("inclination");
    
        // Define minimum and maximum inclinations in milliradians
        // 175 milliradians = ~ 10 degrees
        int88 minimum;
        int88 maximum;
        if (class == WorldClass.Lunar || class == WorldClass.Europan) {
            minimum = 0;
            maximum = 175;
        } else if (class == WorldClass.Terrestrial || class == WorldClass.Panthalassic) {
            minimum = 0;
            maximum = 87;
        } else if (class == WorldClass.Neptunian) {
            minimum = 0;
            maximum = 35;
        } else if (class == WorldClass.Jovian) {
            minimum = 0;
            maximum = 52;
        } else if (class == WorldClass.AsteroidBelt) {
            minimum = 0;
            maximum = 262;
        } else {
            // Not real!
            revert();
        }
        
        // Decide if we should be retrograde (PI-ish inclination)
        int128 real_retrograde_offset = 0;
        if (node.derive("retrograde").d(1, 100, 0) < 3) {
            // This planet ought to move retrograde
            real_retrograde_offset = REAL_PI;
        }

        return real_retrograde_offset + RealMath.div(node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum)), RealMath.toReal(1000));    
    }
    
    // Define the orbit's embedding in the plane (and in time)
    
    /**
     * Get the argument of periapsis (angle from ascending node to periapsis position, in the orbital plane) for a planet or moon.
     */
    function getWorldAop(bytes32 seed) public view onlyControlledAccess returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("AOP");
        // Angles should be uniform from 0 to 2 PI.
        // We already made sure planets/moons wouldn't get too close together when laying out the orbits.
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }
    
    /**
     * Get the mean anomaly (which sweeps from 0 at periapsis to 2 pi at the next periapsis) at epoch (time 0) for a planet or moon.
     */
    function getWorldMeanAnomalyAtEpoch(bytes32 seed) public view onlyControlledAccess returns (int128) {
        RNG.RandNode memory node = RNG.RandNode(seed).derive("MAE");
        // Angles should be uniform from 0 to 2 PI.
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }

    /**
     * Determine if the world is tidally locked, given its seed and its number
     * out from the parent, starting with 0.
     * Overrides getWorldZXAxisAngles and getWorldSpinRate. 
     * Not used for asteroid belts or rings.
     */
    function isTidallyLocked(bytes32 seed, uint16 worldNumber) public view onlyControlledAccess returns (bool) {
        // Tidal lock should be common near the parent and less common further out.
        return RNG.RandNode(seed).derive("tidal_lock").getReal() < RealMath.fraction(1, int88(worldNumber + 1));
    }

    /**
     * Get the Y and X axis angles for a world, in radians.
     * The world's rotation axis starts straight up in its orbital plane.
     * Then the planet is rotated in Y, around the axis by the Y angle.
     * Then it is rotated forward (what would be toward the viewer) in the
     * world's transformed X by the X axis angle.
     * Both angles are in radians.
     * The X angle is never negative, because the Y angle would just be the opposite direction.
     * It is also never greater than Pi, because otherwise we would just measure around the other way.
     * Not used for asteroid belts or rings.
     * For a tidally locked world, ignore these values and use 0 for both angles.
     */
    function getWorldYXAxisAngles(bytes32 seed) public view onlyControlledAccess returns (int128 realYRadians, int128 realXRadians) {
       
        // The Y angle should be uniform over all angles.
        realYRadians = RNG.RandNode(seed).derive("axisy").getRealBetween(-REAL_PI, REAL_PI);

        // The X angle will be mostly small positive or negative, with some sideways and some near Pi/2 (meaning retrograde rotation)
        int16 tilt_die = RNG.RandNode(seed).derive("tilt").d(1, 6, 0);
        
        // Start with low tilt, right side up
        // Earth is like 0.38 radians overall
        int128 real_tilt_limit = REAL_HALF;
        if (tilt_die >= 5) {
            // Be high tilt
            real_tilt_limit = REAL_HALF_PI;
        }
    
        RNG.RandNode memory x_node = RNG.RandNode(seed).derive("axisx");
        realXRadians = x_node.getRealBetween(0, real_tilt_limit);

        if (tilt_die == 4 || tilt_die == 5) {
            // Flip so the tilt we have is relative to upside-down
            realXRadians = REAL_PI - realXRadians;
        }

        // So we should have 1/2 low tilt prograde, 1/6 low tilt retrograde, 1/6 high tilt retrograde, and 1/6 high tilt prograde
    }

    /**
     * Get the spin rate of the world in radians per Julian year around its axis.
     * For a tidally locked world, ignore this value and use the mean angular
     * motion computed by the OrbitalMechanics contract, given the orbit
     * details.
     * Not used for asteroid belts or rings.
     */
    function getWorldSpinRate(bytes32 seed) public view onlyControlledAccess returns (int128) {
        // Earth is something like 2k radians per Julian year.
        return RNG.RandNode(seed).derive("spin").getRealBetween(REAL_ZERO, RealMath.toReal(8000)); 
    }

}
 
