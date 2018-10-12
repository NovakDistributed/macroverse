import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./MacroverseStarGenerator.sol";
import "./MacroverseSystemGenerator.sol";

/**
 * Represents a Macroverse generator for moons around planets.
 *
 * Not part of the system generator to keep it from going over the contract
 * size limit.
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
contract MacroverseMoonGenerator is ControlledAccess {
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
     * Deploy a new copy of the MacroverseMoonGenerator.
     */
    function MacroverseMoonGenerator(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
        // Nothing to do!
    }

    /**
     * Get the number of moons a planet has, using its class. Will sometimes return 0; there is no hasMoons boolean flag to check.
     */
    function getPlanetMoonCount(bytes32 planetSeed, MacroverseSystemGenerator.PlanetClass class) public view onlyControlledAccess returns (uint) {
        var node = RNG.RandNode(planetSeed).derive("mooncount");
        
        uint limit;

        if (class == MacroverseSystemGenerator.PlanetClass.Lunar || class == MacroverseSystemGenerator.PlanetClass.Europan) {
            limit = 3;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Terrestrial || class == MacroverseSystemGenerator.PlanetClass.Panthalassic) {
            limit = 4;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Neptunian) {
            limit = 6;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Jovian) {
            limit = 8;
        } else if (class == MacroverseSystemGenerator.PlanetClass.AsteroidBelt) {
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
     * The actual moon body properties (i.e. mass) are generated with the MacroverseSystemGenerator as if it were a planet.
     */
    function getMoonClass(MacroverseSystemGenerator.PlanetClass parent, bytes32 moonSeed, uint moonNumber) public view onlyControlledAccess
        returns (MacroverseSystemGenerator.PlanetClass) {
        
        // We can have moons of smaller classes than us only.
        // Classes are Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt
        // AsteroidBelts never have moons and never are moons.
        // Asteroidal and Cometary planets only ever are moons.
        // Moons of the same type (rocky or icy) should be more common than cross-type.
        // Jovians can have Neptunian moons

        var moonNode = RNG.RandNode(moonSeed);

        if (moonNumber == 0 && moonNode.derive("ring").d(1, 100, 0) < 15) {
            // This should be a ring
            return MacroverseSystemGenerator.PlanetClass.Ring;
        }

        // Should we be of the opposite ice/rock type to our parent?
        bool crossType = moonNode.derive("crosstype").d(1, 100, 0) < 30;

        // What type is our parent? 0=rock, 1=ice
        uint parentType = uint(parent) / 4;

        // What number is the parent in its type? 0=Asteroidal/Cometary, 3=Jovian/Neptunian
        // The types happen to be arranged so this works.
        uint rankInType = uint(parent) % 4;

        if (parent == MacroverseSystemGenerator.PlanetClass.Jovian && crossType) {
            // Say we can have the gas giant type (Neptunian)
            rankInType++;
        }

        // Roll a lower rank. Bias towards the center.
        uint lowerRank = uint(moonNode.derive("rank").d(2, int8(rankInType), -2) / 2);

        // Determine the type of the moon (0=rock, 1=ice)
        uint moonType = crossType ? parentType : (parentType + 1) % 2;

        return MacroverseSystemGenerator.PlanetClass(moonType * 4 + lowerRank);

    }

    /**
     * Use the mass of a planet to compute its moon scale distance in AU. This is sort of like the Roche limit and must be bigger than the planet's radius.
     */
    function getPlanetMoonScale(bytes32 planetSeed, int128 planetRealMass) public view onlyControlledAccess returns (int128) {
        // We assume a fictional inverse density of 1 cm^3/g = 5.9721986E21 cubic meters per earth mass
        // Then we take cube root of volume / (4/3 pi) to get the radius of such a body
        // Then we derive the scale factor from a few times that.

        var node = RNG.RandNode(planetSeed).derive("moonscale");

        // Get the volume. We can definitely hold Jupiter's volume in m^3
        int128 realVolume = planetRealMass.mul(REAL_M3_PER_EARTH);
        
        // Get the radius in meters
        int128 realRadius = realVolume.div(REAL_PI.mul(RealMath.fraction(4, 3))).pow(RealMath.fraction(1, 3));

        // Return some useful, randomized multiple of it.
        return realRadius.mul(node.getRealBetween(RealMath.fraction(5, 2), RealMath.fraction(7, 2)));
    }

    /**
     * Given the parent planet's scale radius, a moon's seed, the moon's class, and the previous moon's outer clearance (or 0), return the orbit shape of the moon.
     * Other orbit properties come from the system generator.
     */
    function getMoonOrbitDimensions(int128 planetMoonScale, bytes32 seed, MacroverseSystemGenerator.PlanetClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        var moonNode = RNG.RandNode(seed);

        if (class == MacroverseSystemGenerator.PlanetClass.Ring) {
            // Rings are special
            realPeriapsis = realPrevClearance + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringstart").getRealBetween(REAL_ONE, REAL_TWO));
            realApoapsis = realPeriapsis + realPeriapsis.mul(moonNode.derive("ringwidth").getRealBetween(REAL_HALF, REAL_TWO));
            realClearance = realApoapsis + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringclear").getRealBetween(REAL_HALF, REAL_TWO));
            return;
        }

        // Otherwise just roll some stuff
        realPeriapsis = realPrevClearance + planetMoonScale.mul(moonNode.derive("periapsis").getRealBetween(REAL_HALF, REAL_TWO));
        realApoapsis = realPeriapsis.mul(moonNode.derive("apoapsis").getRealBetween(REAL_ONE, RealMath.fraction(120, 100)));

        if (class == MacroverseSystemGenerator.PlanetClass.Asteroidal || class == MacroverseSystemGenerator.PlanetClass.Cometary) {
            // Captured tiny things should be more eccentric
            realApoapsis = realApoapsis + (realApoapsis - realPeriapsis).mul(REAL_TWO);
        }

        realClearance = realApoapsis.mul(moonNode.derive("clearance").getRealBetween(RealMath.fraction(110, 100), RealMath.fraction(160, 100)));
    }

    /**
     * Get the inclination (angle from parent body's equatorial plane to orbital plane at the ascending node) for a moon.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getMoonInclination(bytes32 seed, MacroverseSystemGenerator.PlanetClass class) public view onlyControlledAccess returns (int128) {
        
        var node = RNG.RandNode(seed).derive("inclination");
    
        // Define minimum and maximum inclinations in milliradians
        // 175 milliradians = ~ 10 degrees
        int88 minimum;
        int88 maximum;
        if (class == MacroverseSystemGenerator.PlanetClass.Asteroidal || class == MacroverseSystemGenerator.PlanetClass.Cometary) {
            minimum = 0;
            maximum = 1000;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Lunar || class == MacroverseSystemGenerator.PlanetClass.Europan) {
            minimum = 0;
            maximum = 275;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Terrestrial || class == MacroverseSystemGenerator.PlanetClass.Panthalassic) {
            minimum = 0;
            maximum = 187;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Neptunian) {
            minimum = 0;
            maximum = 135;
        } else if (class == MacroverseSystemGenerator.PlanetClass.Ring) {
            minimum = 0;
            maximum = 362;
        } else {
            // Not real!
            revert();
        }
        
        // Decide if we should be retrograde (PI-ish inclination)
        int128 real_retrograde_offset = 0;
        if (node.derive("retrograde").d(1, 100, 0) < 5) {
            // This moon ought to move retrograde
            real_retrograde_offset = REAL_PI;
        }

        return real_retrograde_offset + RealMath.div(node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum)), RealMath.toReal(1000));    
    }
}
