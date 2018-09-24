pragma solidity ^0.4.18;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./MacroverseStarGenerator.sol";

/**
 * Represents a Macroverse generator for planetary systems around stars and
 * other stellar objects.
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
     * For having moons, we need to be able to run the orbit calculations (all
     * specified in solar masses for the central mass) on
     * Earth-mass-denominated planet masses.
     * See the "Equivalent Planetary masses" table at https://en.wikipedia.org/wiki/Astronomical_system_of_units
     */
    int256 constant EARTH_MASSES_PER_SOLAR_MASS = 332950;

    /**
     * We define the number of earth masses per solar mass as a real, so we don't have to convert it always.
     */
    int128 constant REAL_EARTH_MASSES_PER_SOLAR_MASS = int128(EARTH_MASSES_PER_SOLAR_MASS) * REAL_ONE; 

    /**
     * We also keep a "stowage factor" for planetary material in m^3 per earth mass, at water density, for
     * faking planetary radii during moon orbit calculations.
     */
    int128 constant REAL_M3_PER_EARTH = 6566501804087548000000000000000000; // 6.566501804087548E33

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
    enum PlanetClass {Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt}

    /**
     * Deploy a new copy of the MacroverseSystemGenerator.
     */
    function MacroverseSystemGenerator(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
        // Nothing to do!
    }
    
    /**
     * If the object has any planets at all, get the planet count. Will return
     * nonzero numbers always, so make sure to check getObjectHasPlanets in the
     * Star Generator.
     */
    function getObjectPlanetCount(bytes32 starSeed, MacroverseStarGenerator.ObjectClass objectClass,
        MacroverseStarGenerator.SpectralType spectralType) public view onlyControlledAccess returns (uint) {
        
        var node = RNG.RandNode(starSeed).derive("planetcount");
        
        
        uint limit;

        if (objectClass == MacroverseStarGenerator.ObjectClass.MainSequence) {
            if (spectralType == MacroverseStarGenerator.SpectralType.TypeO ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeB) {
                
                limit = 5;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeA) {
                limit = 7;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeF ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeG ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeK) {
                
                limit = 12;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeM) {
                limit = 14;
            }
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Giant) {
            limit = 2;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Supergiant) {
            limit = 2;
        } else {
           // Black hole, neutron star, or white dwarf
           limit = 2;
        }
        
        var roll = uint(node.getIntBetween(1, int88(limit + 1)));
        
        return roll;
    }

    /**
     * Compute the luminosity of a stellar object given its mass and class.
     * We didn't define this in the star generator, but we need it for the planet generator.
     *
     * Returns luminosity in solar luminosities.
     */
    function getObjectLuminosity(bytes32 starSeed, MacroverseStarGenerator.ObjectClass objectClass, int128 realObjectMass) public view onlyControlledAccess returns (int128) {
        
        var node = RNG.RandNode(starSeed);

        int128 realBaseLuminosity;
        if (objectClass == MacroverseStarGenerator.ObjectClass.BlackHole) {
            // Black hole luminosity is going to be from the accretion disk.
            // See <https://astronomy.stackexchange.com/q/12567>
            // We'll return pretty much whatever and user code can back-fill the accretion disk if any.
            if(node.derive("accretiondisk").getBool()) {
                // These aren't absurd masses; they're on the order of world annual food production per second.
                realBaseLuminosity = node.derive("luminosity").getRealBetween(RealMath.toReal(1), RealMath.toReal(5));
            } else {
                // No accretion disk
                realBaseLuminosity = 0;
            }
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.NeutronStar) {
            // These will be dim and not really mass-related
            realBaseLuminosity = node.derive("luminosity").getRealBetween(RealMath.fraction(1, 20), RealMath.fraction(2, 10));
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.WhiteDwarf) {
            // These are also dim
            realBaseLuminosity = RealMath.pow(realObjectMass.mul(REAL_HALF), RealMath.fraction(35, 10));
        } else {
            // Normal stars follow a normal mass-lumoinosity relationship
            realBaseLuminosity = RealMath.pow(realObjectMass, RealMath.fraction(35, 10));
        }
        
        // Perturb the generated luminosity for fun
        return realBaseLuminosity.mul(node.derive("luminosityScale").getRealBetween(RealMath.fraction(95, 100), RealMath.fraction(105, 100)));
    }

    /**
     * Get the inner and outer boundaries of the habitable zone for a star, in meters, based on its luminosity in solar luminosities.
     * This is just a rule-of-thumb; actual habitability is going to depend on atmosphere (see Venus, Mars)
     */
    function getObjectHabitableZone(int128 realLuminosity) public view onlyControlledAccess returns (int128 realInnerRadius, int128 realOuterRadius) {
        // Light per unit area scales with the square of the distance, so if we move twice as far out we get 1/4 the light.
        // So if our star is half as bright as the sun, the habitable zone radius is 1/sqrt(2) = sqrt(1/2) as big
        // So we scale this by the square root of the luminosity.
        int128 realScale = RealMath.sqrt(realLuminosity);
        // Wikipedia says nobody knows the bounds for Sol, but let's say 0.75 to 2.0 AU to be nice and round and also sort of average
        realInnerRadius = RealMath.toReal(112198400000).mul(realScale);
        realOuterRadius = RealMath.toReal(299195700000).mul(realScale);
    }

    
    /**
     * Get the seed for a planet from the seed for the star and its number.
     */
    function getPlanetSeed(bytes32 starSeed, uint planetNumber) public view onlyControlledAccess returns (bytes32) {
        return RNG.RandNode(starSeed).derive(planetNumber)._hash;
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     * Takes the *planet*'s seed, its number, and the total planets in the system.
     */
    function getPlanetClass(bytes32 seed, uint planetNumber, uint totalPlanets) public view onlyControlledAccess returns (PlanetClass) {
        // TODO: do something based on metallicity?
        var node = RNG.RandNode(seed).derive("class");
        
        var roll = node.getIntBetween(0, 100);
        
        // Inner planets should be more planet-y, ideally smaller
        // Asteroid belts shouldn't be first that often
        
        if (planetNumber == 0 && totalPlanets != 1) {
            // Innermost planet of a multi-planet system
            // No asteroid belts allowed!
            // Also avoid too much watery stuff here because we don't want to deal with the water having been supposed to boil off.
            if (roll < 69) {
                return PlanetClass.Lunar;
            } else if (roll < 70) {
                return PlanetClass.Europan;
            } else if (roll < 79) {
                return PlanetClass.Terrestrial;
            } else if (roll < 80) {
                return PlanetClass.Panthalassic;
            } else if (roll < 90) {
                return PlanetClass.Neptunian;
            } else {
                return PlanetClass.Jovian;
            }
        } else if (planetNumber < totalPlanets / 2) {
            // Inner system
            if (roll < 15) {
                return PlanetClass.Lunar;
            } else if (roll < 20) {
                return PlanetClass.Europan;
            } else if (roll < 35) {
                return PlanetClass.Terrestrial;
            } else if (roll < 40) {
                return PlanetClass.Panthalassic;
            } else if (roll < 70) {
                return PlanetClass.Neptunian;
            } else if (roll < 80) {
                return PlanetClass.Jovian;
            } else {
                return PlanetClass.AsteroidBelt;
            }
        } else {
            // Outer system
            if (roll < 5) {
                return PlanetClass.Lunar;
            } else if (roll < 20) {
                return PlanetClass.Europan;
            } else if (roll < 22) {
                return PlanetClass.Terrestrial;
            } else if (roll < 30) {
                return PlanetClass.Panthalassic;
            } else if (roll < 60) {
                return PlanetClass.Neptunian;
            } else if (roll < 90) {
                return PlanetClass.Jovian;
            } else {
                return PlanetClass.AsteroidBelt;
            }
        }
    }
    
    /**
     * Decide what the mass of the planet is. We can't do even the mass of
     * Jupiter in the ~88 bits we have in a real (should we have used int256 as
     * the backing type?) so we work in Earth masses.
     */
    function getPlanetMass(bytes32 seed, PlanetClass class) public view onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("mass");
        
        if (class == PlanetClass.Lunar) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(9, 100));
        } else if (class == PlanetClass.Europan) {
            return node.getRealBetween(RealMath.fraction(8, 1000), RealMath.fraction(80, 1000));
        } else if (class == PlanetClass.Terrestrial) {
            return node.getRealBetween(RealMath.fraction(10, 100), RealMath.toReal(9));
        } else if (class == PlanetClass.Panthalassic) {
            return node.getRealBetween(RealMath.fraction(80, 1000), RealMath.toReal(9));
        } else if (class == PlanetClass.Neptunian) {
            return node.getRealBetween(RealMath.toReal(7), RealMath.toReal(20));
        } else if (class == PlanetClass.Jovian) {
            return node.getRealBetween(RealMath.toReal(50), RealMath.toReal(400));
        } else if (class == PlanetClass.AsteroidBelt) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(20, 100));
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
     */
    function getPlanetOrbitDimensions(int128 realInnerRadius, int128 realOuterRadius, bytes32 seed, PlanetClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        // We scale all the random generation around the habitable zone distance.

        // Make the planet RNG node to use for all the computations
        var node = RNG.RandNode(seed);
        
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
    function getPlanetPeriapsis(int128 realInnerRadius, int128 realOuterRadius, RNG.RandNode planetNode, PlanetClass class, int128 realPrevClearance)
        internal pure returns (int128) {
        
        // We're going to sample 2 values and take the minimum, to get a nicer distribution than uniform.
        // We really kind of want a log scale but that's expensive.
        var node1 = planetNode.derive("periapsis");
        var node2 = planetNode.derive("periapsis2");
        
        // Define minimum and maximum periapsis distance above previous planet's
        // cleared band. Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar || class == PlanetClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial || class == PlanetClass.Panthalassic) {
            minimum = 20;
            maximum = 70;
        } else if (class == PlanetClass.Neptunian) {
            minimum = 50;
            maximum = 1000;
        } else if (class == PlanetClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == PlanetClass.AsteroidBelt) {
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
    function getPlanetApoapsis(int128 realInnerRadius, int128 realOuterRadius, RNG.RandNode planetNode, PlanetClass class, int128 realPeriapsis)
        internal pure returns (int128) {
        
        var node1 = planetNode.derive("apoapsis");
        var node2 = planetNode.derive("apoapsis2");
        
        // Define minimum and maximum apoapsis distance above planet's periapsis.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar || class == PlanetClass.Europan) {
            minimum = 0;
            maximum = 6;
        } else if (class == PlanetClass.Terrestrial || class == PlanetClass.Panthalassic) {
            minimum = 0;
            maximum = 10;
        } else if (class == PlanetClass.Neptunian) {
            minimum = 20;
            maximum = 500;
        } else if (class == PlanetClass.Jovian) {
            minimum = 10;
            maximum = 200;
        } else if (class == PlanetClass.AsteroidBelt) {
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
    function getPlanetClearance(int128 realInnerRadius, int128 realOuterRadius, RNG.RandNode planetNode, PlanetClass class, int128 realApoapsis)
        internal pure returns (int128) {
        
        var node1 = planetNode.derive("cleared");
        var node2 = planetNode.derive("cleared2");
        
        // Define minimum and maximum clearance.
        // Work in % of the habitable zone inner radius.
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar || class == PlanetClass.Europan) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial || class == PlanetClass.Panthalassic) {
            minimum = 40;
            maximum = 70;
        } else if (class == PlanetClass.Neptunian) {
            minimum = 300;
            maximum = 700;
        } else if (class == PlanetClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == PlanetClass.AsteroidBelt) {
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
     * Get the longitude of the ascending node (angle from galactic +X to ascending node) for a planet.
     */ 
    function getPlanetLan(bytes32 seed) public view onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("LAN");
        // Angles should be uniform from 0 to 2 PI
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }
    
    /**
     * Get the inclination (angle from galactic XZ plane to orbital plane at the ascending node) for a planet.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getPlanetInclination(bytes32 seed, PlanetClass class) public view onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("inclination");
    
        // Define minimum and maximum inclinations in milliradians
        // 175 milliradians = ~ 10 degrees
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar || class == PlanetClass.Europan) {
            minimum = 0;
            maximum = 175;
        } else if (class == PlanetClass.Terrestrial || class == PlanetClass.Panthalassic) {
            minimum = 0;
            maximum = 87;
        } else if (class == PlanetClass.Neptunian) {
            minimum = 0;
            maximum = 35;
        } else if (class == PlanetClass.Jovian) {
            minimum = 0;
            maximum = 52;
        } else if (class == PlanetClass.AsteroidBelt) {
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
     * Get the argument of periapsis (angle from ascending node to periapsis position, in the orbital plane) for a planet.
     */
    function getPlanetAop(bytes32 seed) public view onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("AOP");
        // Angles should be uniform from 0 to 2 PI.
        // We already made sure planets wouldn't get too close together when laying out the orbits.
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }
    
    /**
     * Get the mean anomaly (which sweeps from 0 at periapsis to 2 pi at the next periapsis) at epoch (time 0) for a planet.
     */
    function getPlanetMeanAnomalyAtEpoch(bytes32 seed) public view onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive("MAE");
        // Angles should be uniform from 0 to 2 PI.
        return node.getRealBetween(RealMath.toReal(0), RealMath.mul(RealMath.toReal(2), REAL_PI));
    }

    /**
     * Get the number of moons a planet has, using its class.
     */
    function getPlanetMoonCount(bytes32 planetSeed, PlanetClass class) public view onlyControlledAccess returns (uint) {
        var node = RNG.RandNode(planetSeed).derive("mooncount");
        
        uint limit;

        if (class == PlanetClass.Lunar || class == PlanetClass.Europan) {
            limit = 3;
        } else if (class == PlanetClass.Terrestrial || class == PlanetClass.Panthalassic) {
            limit = 4;
        } else if (class == PlanetClass.Neptunian) {
            limit = 6;
        } else if (class == PlanetClass.Jovian) {
            limit = 8;
        } else if (class == PlanetClass.AsteroidBelt) {
            limit = 0;
        } else {
            // Not real!
            revert();
        }
        
        var roll = uint(node.getIntBetween(0, int88(limit + 1)));
        
        return roll;
    }

    /**
     * Get the seed for a moon from the seed for the planet and its number.
     */
    function getMoonSeed(bytes32 planetSeed, uint moonNumber) public view onlyControlledAccess returns (bytes32) {
        return RNG.RandNode(planetSeed).derive(moonNumber)._hash;
    }

    /**
     * Get the class of a moon, given the moon's seed and the class of its parent planet.
     */
    function getMoonClass(PlanetClass parent, bytes32 moonSeed, uint moonNumber) public view onlyControlledAccess returns (PlanetClass) {
        // We can have moons of smaller classes than us only.
        // Classes are Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt
        // AsteroidBelts never have moons and never are moons.
        // Asteroidal and Cometary planets only ever are moons.
        // Moons of the same type (rocky or icy) should be more common than cross-type.
        // Jovians can have Neptunian moons

        var moonNode = RNG.RandNode(moonSeed);

        if (moonNumber == 0 && moonNode.derive("ring").d(1, 100, 0) < 15) {
            // This should be a ring
            return PlanetClass.Ring;
        }

        // Should we be of the opposite ice/rock type to our parent?
        bool crossType = moonNode.derive("crosstype").d(1, 100, 0) < 30;

        // What type is our parent? 0=rock, 1=ice
        uint parentType = uint(parent) / 4;

        // What number is the parent in its type? 0=Asteroidal/Cometary, 3=Jovian/Neptunian
        // The types happen to be arranged so this works.
        uint rankInType = uint(parent) % 4;

        if (parent == PlanetClass.Jovian && crossType) {
            // Say we can have the gas giant type (Neptunian)
            rankInType++;
        }

        // Roll a lower rank. Bias towards the center.
        uint lowerRank = uint(moonNode.derive("rank").d(2, int8(rankInType), -2) / 2);

        // Determine the type of the moon (0=rock, 1=ice)
        uint moonType = crossType ? parentType : (parentType + 1) % 2;

        return PlanetClass(moonType * 4 + lowerRank);

    }

    /**
     * Use the mass of a planet to compute its moon scale distance in AU. This is sort of like the Roche limit and must be bigger than the planet's radius.
     */
    function getPlanetMoonScale(int128 realMass) public view onlyControlledAccess returns (int128) {
        // We assume a fictional inverse density of 1 cm^3/g = 5.9721986E21 cubic meters per earth mass
        // Then we take cube root of volume / (4/3 pi) to get the radius of such a body
        // Then we derive the scale factor from a few times that.

        // Get the volume. We can definitely hold Jupiter's volume in m^3
        int128 realVolume = realMass.mul(REAL_M3_PER_EARTH);
        
        // Get the radius in meters
        int128 realRadius = realVolume.div(REAL_PI.mul(RealMath.fraction(4, 3))).pow(RealMath.fraction(1, 3));

        // Return some useful multiple of it.
        return realRadius.mul(RealMath.toReal(3));
    }

    /**
     * Given the parent planet's scale radius, a moon's seed, the moon's class, and the previous moon's outer clearance (or 0), return the orbit shape of the moon.
     */
    function getPlanetOrbitDimensions(int128 planetMoonScale, bytes32 seed, PlanetClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        var moonNode = RNG.RandNode(seed);

        if (class == PlanetClass.Ring) {
            // Rings are special
            realPeriapsis = realPrevClearance + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringstart").getRealBetween(REAL_ONE, REAL_TWO));
            realApoapsis = realPeriapsis + realPeriapsis.mul(moonNode.derive("ringwidth").getRealBetween(REAL_HALF, REAL_TWO));
            realClearance = realApoapsis + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringclear").getRealBetween(REAL_HALF, REAL_TWO));
            return;
        }

        // Otherwise just roll some stuff
        realPeriapsis = realPrevClearance + planetMoonScale.mul(moonNode.derive("periapsis").getRealBetween(REAL_HALF, REAL_TWO));
        realApoapsis = realPeriapsis.mul(moonNode.derive("apoapsis").getRealBetween(REAL_ONE, RealMath.fraction(120, 100)));
        realClearance = realApoapsis.mul(moonNode.derive("clearance").getRealBetween(RealMath.fraction(110, 100), RealMath.fraction(160, 100)));
    }

}
 
