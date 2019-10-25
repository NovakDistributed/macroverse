pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoEther.sol";
import "./HasNoContracts.sol";

import "./MacroverseNFTUtils.sol";
import "./MacroverseStarGenerator.sol";
import "./MacroverseStarGeneratorPatch1.sol";
import "./MacroverseSystemGenerator.sol";
import "./MacroverseMoonGenerator.sol";
import "./Macroverse.sol";

/**
 * The MacroverseExistenceChecker queries Macroverse generator contracts to
 * determine if a particular thing (e.g. the nth planet of such-and-such a
 * star) exists in the Macroverse world.
 *
 * It does not need to be ControlledAccess because the Macroverse contracts it
 * calls into are. It does not have defenses against receiving stuck Ether and
 * tokens because it is not intended to be involved in end-user token
 * transactions in any capacity.
 *
 * Serves as an example for how Macroverse can be queried from on-chain logic.
 */
contract MacroverseExistenceChecker {

    using MacroverseNFTUtils for uint256;

    // These constants are shared with the TokenUtils library

    // Define the types of tokens that can exist
    uint256 constant TOKEN_TYPE_SECTOR = 0;
    uint256 constant TOKEN_TYPE_SYSTEM = 1;
    uint256 constant TOKEN_TYPE_PLANET = 2;
    uint256 constant TOKEN_TYPE_MOON = 3;
    // Land tokens are a range of type field values.
    // Land tokens of the min type use one trixel field
    uint256 constant TOKEN_TYPE_LAND_MIN = 4;
    uint256 constant TOKEN_TYPE_LAND_MAX = 31;

    // Sentinel for no moon used (for land on a planet)
    uint16 constant MOON_NONE = 0xFFFF;

    // These constants are shared with the generator contracts

    // How far out does the sector system extend?
    int16 constant MAX_SECTOR = 10000;

    //////////////
    // Contract state
    //////////////

    // Keep track of all of the generator contract addresses
    MacroverseStarGenerator private starGenerator;
    MacroverseStarGeneratorPatch1 private starGeneratorPatch;
    MacroverseSystemGenerator private systemGenerator;
    MacroverseMoonGenerator private moonGenerator;

    /**
     * Deploy a new copy of the Macroverse Existence Checker.
     *
     * The given generator contracts will be queried.
     */
    constructor(address starGeneratorAddress, address starGeneratorPatchAddress,
        address systemGeneratorAddress, address moonGeneratorAddress) public {

        // Remember where all the generators are
        starGenerator = MacroverseStarGenerator(starGeneratorAddress);
        starGeneratorPatch = MacroverseStarGeneratorPatch1(starGeneratorPatchAddress);
        systemGenerator = MacroverseSystemGenerator(systemGeneratorAddress);
        moonGenerator = MacroverseMoonGenerator(moonGeneratorAddress);
        
    }

    /**
     * Return true if a sector with the given coordinates exists in the
     * Macroverse universe, and false otherwise.
     */
    function sectorExists(int16 sectorX, int16 sectorY, int16 sectorZ) public pure returns (bool) {
        // Enforce absolute bounds.
        if (sectorX > MAX_SECTOR) return false;
        if (sectorY > MAX_SECTOR) return false;
        if (sectorZ > MAX_SECTOR) return false;
        if (sectorX < -MAX_SECTOR) return false;
        if (sectorY < -MAX_SECTOR) return false;
        if (sectorZ < -MAX_SECTOR) return false;

        return true;
    }

    /**
     * Determine if the given system (which might be a star, black hole, etc.)
     * exists in the given sector. If the sector doesn't exist, returns false.
     */
    function systemExists(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 system) public view returns (bool) {
        if (!sectorExists(sectorX, sectorY, sectorZ)) {
            // The system can't exist if the sector doesn't.
            return false;
        }

        // If the sector does exist, the system exists if it is in bounds
        return (system < starGenerator.getSectorObjectCount(sectorX, sectorY, sectorZ));
    }


    /**
     * Determine if the given planet exists, and if so returns some information
     * generated about it for re-use.
     */
    function planetExistsVerbose(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 system, uint16 planet) internal view returns (bool exists,
        bytes32 systemSeed, uint16 totalPlanets) {

        if (!systemExists(sectorX, sectorY, sectorZ, system)) {
            // The planet can't exist if the parent system doesn't.
            exists = false;
        } else {
            // Get the system seed for the parent star/black hole/whatever
            // TODO: unify with above to save on derives?
            systemSeed = starGenerator.getSectorObjectSeed(sectorX, sectorY, sectorZ, system);

            // Get class and spectral type
            MacroverseStarGenerator.ObjectClass systemClass = starGenerator.getObjectClass(systemSeed);
            MacroverseStarGenerator.SpectralType systemType = starGenerator.getObjectSpectralType(systemSeed, systemClass);

            if (starGenerator.getObjectHasPlanets(systemSeed, systemClass, systemType)) {
                // There are some planets. Are there enough?
                totalPlanets = starGeneratorPatch.getObjectPlanetCount(systemSeed, systemClass, systemType);
                exists = (planet < totalPlanets);
            } else {
                // This system doesn't actually have planets
                exists = false;
            }
        }
    }

    /**
     * Determine if the given moon exists, and if so returns some information
     * generated about it for re-use.
     */
    function moonExistsVerbose(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 system, uint16 planet, uint16 moon) public view returns (bool exists,
        bytes32 planetSeed, Macroverse.WorldClass planetClass) {
        
        (bool havePlanet, bytes32 systemSeed, uint16 totalPlanets) = planetExistsVerbose(sectorX, sectorY, sectorZ, system, planet);

        if (!havePlanet) {
            // Moon can't exist without its planet
            exists = false;
        } else {

            // Otherwise, work out the seed of the planet.
            planetSeed = systemGenerator.getWorldSeed(systemSeed, planet);
            
            // Use it to get the class of the planet, which is important for knowing if there is a moon
            planetClass = systemGenerator.getPlanetClass(planetSeed, planet, totalPlanets);

            // Count its moons
            uint16 moonCount = moonGenerator.getPlanetMoonCount(planetSeed, planetClass);

            // This moon exists if it is less than the count
            exists = (moon < moonCount);
        }
    }

    /**
     * Determine if the given planet exists.
     */
    function planetExists(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 system, uint16 planet) public view returns (bool) {
        // Get only one return value. Ignore the others with these extra commas
        (bool exists, , ) = planetExistsVerbose(sectorX, sectorY, sectorZ, system, planet);

        // Caller only cares about existence
        return exists;
    }

    /**
     * Determine if the given moon exists.
     */
    function moonExists(int16 sectorX, int16 sectorY, int16 sectorZ, uint16 system, uint16 planet, uint16 moon) public view returns (bool) {
        // Get only the existence flag
        (bool exists, , ) = moonExistsVerbose(sectorX, sectorY, sectorZ, system, planet, moon);
    
        // Return it
        return exists;
    }

    /**
     * Determine if the thing referred to by the given packed NFT token number
     * exists.
     *
     * Token is assumed to be canonical/valid. Use MacroverseNFTUtils
     * tokenIsCanonical() to validate it first.
     */
    function exists(uint256 token) public view returns (bool) {
        // Get the type
        uint256 tokenType = token.getTokenType();

        // Unpack the sector. There's always a sector.
        (int16 sectorX, int16 sectorY, int16 sectorZ) = token.getTokenSector();

        if (tokenType == TOKEN_TYPE_SECTOR) {
            // Check if the requested sector exists
            return sectorExists(sectorX, sectorY, sectorZ);
        }

        // There must be a system number
        uint16 system = token.getTokenSystem();

        if (tokenType == TOKEN_TYPE_SYSTEM) {
            // Check if the requested system exists
            return systemExists(sectorX, sectorY, sectorZ, system);
        }

        // There must be a planet number
        uint16 planet = token.getTokenPlanet();

        // And there may be a moon
        uint16 moon = token.getTokenMoon();

        if (tokenType == TOKEN_TYPE_PLANET) {
            // We exist if the planet exists.
            // TODO: maybe check for ring/asteroid field types and don't let their land exist at all?
            return planetExists(sectorX, sectorY, sectorZ, system, planet);
        }

        if (tokenType == TOKEN_TYPE_MOON) {
             // We exist if the moon exists
            return moonExists(sectorX, sectorY, sectorZ, system, planet, moon);
        }

        // Otherwise it must be land.
        assert(token.tokenIsLand());

        // We exist if the planet or moon exists and isn't a ring or asteroid belt
        // We need the parent existence flag
        bool haveParent;
        // We will need a seed scratch.
        bytes32 seed;

        if (moon == MOON_NONE) {
            // Make sure the planet exists and isn't a ring
            uint16 totalPlanets;
            (haveParent, seed, totalPlanets) = planetExistsVerbose(sectorX, sectorY, sectorZ, system, planet);

            if (!haveParent) {
                return false;
            }

            // Get the planet's seed
            seed = systemGenerator.getWorldSeed(seed, planet);

            // Land exists if the planet isn't an AsteroidBelt
            return systemGenerator.getPlanetClass(seed, planet, totalPlanets) != Macroverse.WorldClass.AsteroidBelt;

        } else {
            // Make sure the moon exists and isn't a ring
            Macroverse.WorldClass planetClass;
            (haveParent, seed, planetClass) = moonExistsVerbose(sectorX, sectorY, sectorZ, system, planet, moon);

            if (!haveParent) {
                return false;
            }

            // Get the moon's seed
            seed = systemGenerator.getWorldSeed(seed, moon);

            // Land exists if the moon isn't a Ring
            return moonGenerator.getMoonClass(planetClass, seed, moon) != Macroverse.WorldClass.Ring;
        }
    }

}
