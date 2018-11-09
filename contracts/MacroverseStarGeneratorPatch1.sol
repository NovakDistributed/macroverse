pragma solidity ^0.4.18;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./MacroverseStarGenerator.sol";

/**
 * Provides extra methods not present in the original MacroverseStarGenerator
 * that generate new properties of the galaxy's stars. Meant to be deployed and
 * queried alongside the original.
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
contract MacroverseStarGeneratorPatch1 is ControlledAccess {
    // TODO: RNG doesn't get linked against because we can't pass the struct to the library...
    using RNG for *;
    using RealMath for *;
    // No SafeMath or it might confuse RealMath

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
     * Deploy a new copy of the patch generator.
     * Use the contract at the given address to regulate access.
     */
    function MacroverseStarGeneratorPatch1(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) public {
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

    

}
 
