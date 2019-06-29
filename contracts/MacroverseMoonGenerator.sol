pragma solidity ^0.4.24;

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
    int128 constant REAL_M3_PER_EARTH = 6566501804087548000000000000000000; // 6.566501804087548E33 as an int, 5.97219E21 m^3/earth

    /**
     * Deploy a new copy of the MacroverseMoonGenerator.
     */
    constructor(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
        // Nothing to do!
    }

    /**
     * Get the number of moons a planet has, using its class. Will sometimes return 0; there is no hasMoons boolean flag to check.
     * The seed of each moon is obtained from the MacroverseSystemGenerator.
     */
    function getPlanetMoonCount(bytes32 planetSeed, MacroverseSystemGenerator.WorldClass class) public view onlyControlledAccess returns (uint16) {
        RNG.RandNode memory node = RNG.RandNode(planetSeed).derive("mooncount");
        
        uint16 limit;

        if (class == MacroverseSystemGenerator.WorldClass.Lunar || class == MacroverseSystemGenerator.WorldClass.Europan) {
            limit = 3;
        } else if (class == MacroverseSystemGenerator.WorldClass.Terrestrial || class == MacroverseSystemGenerator.WorldClass.Panthalassic) {
            limit = 4;
        } else if (class == MacroverseSystemGenerator.WorldClass.Neptunian) {
            limit = 6;
        } else if (class == MacroverseSystemGenerator.WorldClass.Jovian) {
            limit = 8;
        } else if (class == MacroverseSystemGenerator.WorldClass.AsteroidBelt) {
            limit = 0;
        } else {
            // Not real!
            revert();
        }
        
        uint16 roll = uint16(node.getIntBetween(0, int88(limit + 1)));
        
        return roll;
    }

    /**
     * Get the class of a moon, given the moon's seed and the class of its parent planet.
     * The seed of each moon is obtained from the MacroverseSystemGenerator.
     * The actual moon body properties (i.e. mass) are generated with the MacroverseSystemGenerator as if it were a planet.
     */
    function getMoonClass(MacroverseSystemGenerator.WorldClass parent, bytes32 moonSeed, uint16 moonNumber) public view onlyControlledAccess
        returns (MacroverseSystemGenerator.WorldClass) {
        
        // We can have moons of smaller classes than us only.
        // Classes are Asteroidal, Lunar, Terrestrial, Jovian, Cometary, Europan, Panthalassic, Neptunian, Ring, AsteroidBelt
        // AsteroidBelts never have moons and never are moons.
        // Asteroidal and Cometary planets only ever are moons.
        // Moons of the same type (rocky or icy) should be more common than cross-type.
        // Jovians can have Neptunian moons

        RNG.RandNode memory moonNode = RNG.RandNode(moonSeed);

        if (moonNumber == 0 && moonNode.derive("ring").d(1, 100, 0) < 15) {
            // This should be a ring
            return MacroverseSystemGenerator.WorldClass.Ring;
        }

        // Should we be of the opposite ice/rock type to our parent?
        bool crossType = moonNode.derive("crosstype").d(1, 100, 0) < 30;

        // What type is our parent? 0=rock, 1=ice
        uint parentType = uint(parent) / 4;

        // What number is the parent in its type? 0=Asteroidal/Cometary, 3=Jovian/Neptunian
        // The types happen to be arranged so this works.
        uint rankInType = uint(parent) % 4;

        if (parent == MacroverseSystemGenerator.WorldClass.Jovian && crossType) {
            // Say we can have the gas giant type (Neptunian)
            rankInType++;
        }

        // Roll a lower rank. Bias towards the center.
        uint lowerRank = uint(moonNode.derive("rank").d(2, int8(rankInType), -2) / 2);

        // Determine the type of the moon (0=rock, 1=ice)
        uint moonType = crossType ? parentType : (parentType + 1) % 2;

        return MacroverseSystemGenerator.WorldClass(moonType * 4 + lowerRank);

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
    function getMoonOrbitDimensions(int128 planetMoonScale, bytes32 seed, MacroverseSystemGenerator.WorldClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        RNG.RandNode memory moonNode = RNG.RandNode(seed);

        if (class == MacroverseSystemGenerator.WorldClass.Ring) {
            // Rings are special
            realPeriapsis = realPrevClearance + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringstart").getRealBetween(REAL_ONE, REAL_TWO));
            realApoapsis = realPeriapsis + realPeriapsis.mul(moonNode.derive("ringwidth").getRealBetween(REAL_HALF, REAL_TWO));
            realClearance = realApoapsis + planetMoonScale.mul(REAL_HALF).mul(moonNode.derive("ringclear").getRealBetween(REAL_HALF, REAL_TWO));
            return;
        }

        // Otherwise just roll some stuff
        realPeriapsis = realPrevClearance + planetMoonScale.mul(moonNode.derive("periapsis").getRealBetween(REAL_HALF, REAL_ONE));
        realApoapsis = realPeriapsis.mul(moonNode.derive("apoapsis").getRealBetween(REAL_ONE, RealMath.fraction(120, 100)));

        if (class == MacroverseSystemGenerator.WorldClass.Asteroidal || class == MacroverseSystemGenerator.WorldClass.Cometary) {
            // Captured tiny things should be more eccentric
            realApoapsis = realApoapsis + (realApoapsis - realPeriapsis).mul(REAL_TWO);
        }

        realClearance = realApoapsis.mul(moonNode.derive("clearance").getRealBetween(RealMath.fraction(110, 100), RealMath.fraction(130, 100)));
    }

    /**
     * Get the inclination (angle from parent body's equatorial plane to orbital plane at the ascending node) for a moon.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getMoonInclination(bytes32 seed, MacroverseSystemGenerator.WorldClass class) public view onlyControlledAccess returns (int128 real_inclination) {
        
        RNG.RandNode memory node = RNG.RandNode(seed).derive("inclination");

        // Define maximum inclination in milliradians
        // 175 milliradians = ~ 10 degrees
        int88 maximum;
        // Inclination is freer for moons than for planets
        if (class == MacroverseSystemGenerator.WorldClass.Asteroidal || class == MacroverseSystemGenerator.WorldClass.Cometary) {
            // Tiny captured things can be pretty free
            maximum = 850;
        } else if (class == MacroverseSystemGenerator.WorldClass.Lunar || class == MacroverseSystemGenerator.WorldClass.Europan) {
            maximum = 200;
        } else if (class == MacroverseSystemGenerator.WorldClass.Terrestrial || class == MacroverseSystemGenerator.WorldClass.Panthalassic) {
            maximum = 180;
        } else if (class == MacroverseSystemGenerator.WorldClass.Neptunian) {
            maximum = 150;
        } else if (class == MacroverseSystemGenerator.WorldClass.Ring) {
            // Rings can do almost anything they want (up to like 1.5 radians).
            maximum = 1500;
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
