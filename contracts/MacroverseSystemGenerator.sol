pragma solidity ^0.4.24;

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./Macroverse.sol";
import "./MacroverseSystemGeneratorPart1.sol";
import "./MacroverseSystemGeneratorPart2.sol";

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
        return MacroverseSystemGeneratorPart1.getWorldSeed(parentSeed, childNumber);
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     * Takes the *planet*'s seed, its number, and the total planets in the system.
     */
    function getPlanetClass(bytes32 seed, uint16 planetNumber, uint16 totalPlanets) public view onlyControlledAccess returns (Macroverse.WorldClass) {
        return MacroverseSystemGeneratorPart1.getPlanetClass(seed, planetNumber, totalPlanets);
    }
    
    /**
     * Decide what the mass of the planet or moon is. We can't do even the mass of
     * Jupiter in the ~88 bits we have in a real (should we have used int256 as
     * the backing type?) so we work in Earth masses.
     *
     * Also produces the masses for moons.
     */
    function getWorldMass(bytes32 seed, Macroverse.WorldClass class) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart1.getWorldMass(seed, class);
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
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {
        
        return MacroverseSystemGeneratorPart1.getPlanetOrbitDimensions(realInnerRadius, realOuterRadius, seed, class, realPrevClearance);
    }

    /**
     * Convert from periapsis and apoapsis to semimajor axis and eccentricity.
     */
    function convertOrbitShape(int128 realPeriapsis, int128 realApoapsis) public view onlyControlledAccess returns (int128 realSemimajor, int128 realEccentricity) {
        return MacroverseSystemGeneratorPart2.convertOrbitShape(realPeriapsis, realApoapsis);
    }
    
    // Define the orbital plane
    
    /**
     * Get the longitude of the ascending node for a planet or moon. For
     * planets, this is the angle from system +X to ascending node. For
     * moons, we use system +X transformed into the planet's equatorial plane
     * by the equatorial plane/rotation axis angles.
     */ 
    function getWorldLan(bytes32 seed) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart2.getWorldLan(seed);
    }
    
    /**
     * Get the inclination (angle from system XZ plane to orbital plane at the ascending node) for a planet.
     * For a moon, this is done in the moon generator instead.
     * Inclination is always positive. If it were negative, the ascending node would really be the descending node.
     * Result is a real in radians.
     */ 
    function getPlanetInclination(bytes32 seed, Macroverse.WorldClass class) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart2.getPlanetInclination(seed, class);
    }
    
    // Define the orbit's embedding in the plane (and in time)
    
    /**
     * Get the argument of periapsis (angle from ascending node to periapsis position, in the orbital plane) for a planet or moon.
     */
    function getWorldAop(bytes32 seed) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart2.getWorldAop(seed);
    }
    
    /**
     * Get the mean anomaly (which sweeps from 0 at periapsis to 2 pi at the next periapsis) at epoch (time 0) for a planet or moon.
     */
    function getWorldMeanAnomalyAtEpoch(bytes32 seed) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart2.getWorldMeanAnomalyAtEpoch(seed);
    }

    /**
     * Determine if the world is tidally locked, given its seed and its number
     * out from the parent, starting with 0.
     * Overrides getWorldZXAxisAngles and getWorldSpinRate. 
     * Not used for asteroid belts or rings.
     */
    function isTidallyLocked(bytes32 seed, uint16 worldNumber) public view onlyControlledAccess returns (bool) {
        return MacroverseSystemGeneratorPart2.isTidallyLocked(seed, worldNumber);
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
        return MacroverseSystemGeneratorPart2.getWorldYXAxisAngles(seed); 
    }

    /**
     * Get the spin rate of the world in radians per Julian year around its axis.
     * For a tidally locked world, ignore this value and use the mean angular
     * motion computed by the OrbitalMechanics contract, given the orbit
     * details.
     * Not used for asteroid belts or rings.
     */
    function getWorldSpinRate(bytes32 seed) public view onlyControlledAccess returns (int128) {
        return MacroverseSystemGeneratorPart2.getWorldSpinRate(seed);
    }

}
 
