pragma solidity ^0.5.2;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./MacroverseStarGenerator.sol";
import "./MacroverseSystemGenerator.sol";
import "./Macroverse.sol";

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
    int128 constant REAL_M3_PER_EARTH = 6566501804087548000000000000000000; // 6.566501804087548E33 as an int, 5.97219E21 m^3/earth

    /**
     * Deploy a new copy of the MacroverseMoonGenerator.
     */
    constructor(address accessControlAddress) ControlledAccess(accessControlAddress) public {
        // Nothing to do!
    }

    /**
     * Get the number of moons a planet has, using its class. Will sometimes return 0; there is no hasMoons boolean flag to check.
     * The seed of each moon is obtained from the MacroverseSystemGenerator.
     */
    function getPlanetMoonCount(bytes32 planetSeed, Macroverse.WorldClass class) public view onlyControlledAccess returns (uint16) {
        // We will roll n of this kind of die and subtract n to get our moon count
        int8 die;
        int8 n = 2;
        // We can also divide by this
        int8 divisor = 1;

        if (class == Macroverse.WorldClass.Lunar || class == Macroverse.WorldClass.Europan) {
            die = 2;
            divisor = 2;
            // (2d2 - 2) / 2 = 25% chance of 1, 75% chance of 0
        } else if (class == Macroverse.WorldClass.Terrestrial || class == Macroverse.WorldClass.Panthalassic) {
            die = 3;
            // 2d3-2: https://www.wolframalpha.com/input/?i=roll+2d3
        } else if (class == Macroverse.WorldClass.Neptunian) {
            die = 8;
            n = 2;
            divisor = 2;
        } else if (class == Macroverse.WorldClass.Jovian) {
            die = 6;
            n = 3;
            divisor = 2;
        } else if (class == Macroverse.WorldClass.AsteroidBelt) {
            // Just no moons here
            return 0;
        } else {
            // Not real!
            revert();
        }
        
        RNG.RandNode memory node = RNG.RandNode(planetSeed).derive("mooncount");

        uint16 roll = uint16(node.d(n, die, -n) / int88(divisor));
        
        return roll;
    }

    /**
     * Get the class of a moon, given the moon's seed and the class of its parent planet.
     * The seed of each moon is obtained from the MacroverseSystemGenerator.
     * The actual moon body properties (i.e. mass) are generated with the MacroverseSystemGenerator as if it were a planet.
     */
    function getMoonClass(Macroverse.WorldClass parent, bytes32 moonSeed, uint16 moonNumber) public view onlyControlledAccess
        returns (Macroverse.WorldClass) {
        
        // We can have moons of smaller classes than us only.
        // Classes are Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt
        // AsteroidBelts never have moons and never are moons.
        // Asteroidal and Cometary planets only ever are moons.
        // Moons of the same type (rocky or icy) should be more common than cross-type.
        // Jovians can have Neptunian moons

        RNG.RandNode memory moonNode = RNG.RandNode(moonSeed);

        if (moonNumber == 0 && moonNode.derive("ring").d(1, 100, 0) < 20) {
            // This should be a ring
            return Macroverse.WorldClass.Ring;
        }

        // Should we be of the opposite ice/rock type to our parent?
        bool crossType = moonNode.derive("crosstype").d(1, 100, 0) < 30;

        // What type is our parent? 0=rock, 1=ice
        uint parentType = uint(parent) / 4;

        // What number is the parent in its type? 0=Asteroidal/Cometary, 3=Jovian/Neptunian
        // The types happen to be arranged so this works.
        uint rankInType = uint(parent) % 4;

        if (parent == Macroverse.WorldClass.Jovian && crossType) {
            // Say we can have the gas giant type (Neptunian)
            rankInType++;
        }

        // Roll a lower rank. Bias upward by subtracting 1 instead of 2, so we more or less round up.
        uint lowerRank = uint(moonNode.derive("rank").d(2, int8(rankInType), -1) / 2);

        // Determine the type of the moon (0=rock, 1=ice)
        uint moonType = crossType ? parentType : (parentType + 1) % 2;

        return Macroverse.WorldClass(moonType * 4 + lowerRank);

    }

    /**
     * Use the mass of a planet to compute its moon scale distance in AU. This is sort of like the Roche limit and must be bigger than the planet's radius.
     */
    function getPlanetMoonScale(bytes32 planetSeed, int128 planetRealMass) public view onlyControlledAccess returns (int128) {
        // We assume a fictional inverse density of 1 cm^3/g = 5.9721986E21 cubic meters per earth mass
        // Then we take cube root of volume / (4/3 pi) to get the radius of such a body
        // Then we derive the scale factor from a few times that.

        RNG.RandNode memory node = RNG.RandNode(planetSeed).derive("moonscale");

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
    function getMoonOrbitDimensions(int128 planetMoonScale, bytes32 seed, Macroverse.WorldClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        RNG.RandNode memory moonNode = RNG.RandNode(seed);

        if (class == Macroverse.WorldClass.Ring) {
            // Rings are special
            realPeriapsis = realPrevClearance + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringstart").getRealBetween(REAL_ONE, REAL_TWO));
            realApoapsis = realPeriapsis + realPeriapsis.mul(moonNode.derive("ringwidth").getRealBetween(REAL_HALF, REAL_TWO));
            realClearance = realApoapsis + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringclear").getRealBetween(REAL_HALF, REAL_TWO));
        } else {
            // Otherwise just roll some stuff
            realPeriapsis = realPrevClearance + planetMoonScale.mul(moonNode.derive("periapsis").getRealBetween(REAL_HALF, REAL_ONE));
            realApoapsis = realPeriapsis.mul(moonNode.derive("apoapsis").getRealBetween(REAL_ONE, RealMath.fraction(120, 100)));

            if (class == Macroverse.WorldClass.Asteroidal || class == Macroverse.WorldClass.Cometary) {
                // Captured tiny things should be more eccentric
                realApoapsis = realApoapsis + (realApoapsis - realPeriapsis).mul(REAL_TWO);
            }

            realClearance = realApoapsis.mul(moonNode.derive("clearance").getRealBetween(RealMath.fraction(110, 100), RealMath.fraction(130, 100)));
        }
    }

    /**
     * Get the inclination (angle from parent body's equatorial plane to orbital plane at the ascending node) for a moon.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getMoonInclination(bytes32 seed, Macroverse.WorldClass class) public view onlyControlledAccess returns (int128 real_inclination) {
        
        RNG.RandNode memory node = RNG.RandNode(seed).derive("inclination");

        // Define maximum inclination in milliradians
        // 175 milliradians = ~ 10 degrees
        int88 maximum;
        if (class == Macroverse.WorldClass.Asteroidal || class == Macroverse.WorldClass.Cometary) {
            // Tiny captured things can be pretty free
            maximum = 850;
        } else if (class == Macroverse.WorldClass.Lunar || class == Macroverse.WorldClass.Europan) {
            maximum = 100;
        } else if (class == Macroverse.WorldClass.Terrestrial || class == Macroverse.WorldClass.Panthalassic) {
            maximum = 80;
        } else if (class == Macroverse.WorldClass.Neptunian) {
            maximum = 50;
        } else if (class == Macroverse.WorldClass.Ring) {
            maximum = 350;
        } else {
            // Not real!
            revert();
        }
        
        // Compute the inclination
        real_inclination = node.getRealBetween(0, RealMath.toReal(maximum)).div(RealMath.toReal(1000));

        if (node.derive("retrograde").d(1, 100, 0) < 10) {
            // This moon ought to move retrograde (subtract inclination from pi instead of adding it to 0)
            real_inclination = REAL_PI - real_inclination;
        }

        return real_inclination;  
    }
}
