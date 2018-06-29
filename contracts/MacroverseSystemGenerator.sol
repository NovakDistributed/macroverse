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
     * It is also useful to have Pi around.
     * We can't pull it in from the library.
     */
    int128 constant REAL_PI = 3454217652358;

    /**
     * Define different types of planet.
     */
    enum PlanetClass {Lunar, Terrestrial, Uranian, Jovian, AsteroidBelt}

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
        MacroverseStarGenerator.SpectralType spectralType) public view onlyControlledAccess returns (int16) {
        
        var node = RNG.RandNode(starSeed).derive("planetcount");
        
        
        int16 limit;

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
        
        var roll = int16(node.getIntBetween(1, limit));
        
        return roll;
    }
    
    /**
     * Get the seed for a planet from the seed for the star and its number.
     */
    function getPlanetSeed(bytes32 starSeed, int16 planetNumber) public view onlyControlledAccess returns (bytes32) {
        return RNG.RandNode(starSeed).derive(planetNumber)._hash;
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     * Takes the *planet*'s seed, its number, and the total planets in the system.
     */
    function getPlanetClass(bytes32 seed, int16 planetNumber, int16 totalPlanets) public view onlyControlledAccess returns (PlanetClass) {
        // TODO: do something based on metallicity?
        var node = RNG.RandNode(seed).derive("class");
        
        var roll = node.getIntBetween(1, 100);
        
        // Inner planets should be more planet-y, ideally smaller
        // Asteroid belts shouldn't be first that often
        
        if (planetNumber == 0 && totalPlanets != 1) {
            // Innermost planet of a multi-planet system
            // No asteroid belts allowed!
            if (roll < 70) {
                return PlanetClass.Lunar;
            } else if (roll < 80) {
                return PlanetClass.Terrestrial;
            } else if (roll < 90) {
                return PlanetClass.Uranian;
            } else {
                return PlanetClass.Jovian;
            }
        } else if (planetNumber < totalPlanets / 2) {
            // Inner system
            if (roll < 20) {
                return PlanetClass.Lunar;
            } else if (roll < 40) {
                return PlanetClass.Terrestrial;
            } else if (roll < 70) {
                return PlanetClass.Uranian;
            } else if (roll < 80) {
                return PlanetClass.Jovian;
            } else {
                return PlanetClass.AsteroidBelt;
            }
        } else {
            // Outer system
            if (roll < 20) {
                return PlanetClass.Lunar;
            } else if (roll < 30) {
                return PlanetClass.Terrestrial;
            } else if (roll < 60) {
                return PlanetClass.Uranian;
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
        } else if (class == PlanetClass.Terrestrial) {
            return node.getRealBetween(RealMath.fraction(10, 100), RealMath.toReal(9));
        } else if (class == PlanetClass.Uranian) {
            return node.getRealBetween(RealMath.toReal(9), RealMath.toReal(20));
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

    event Explode(int88 data);

    /**
     * Given the parent star class and type, the planet seed, the planet class
     * to be generated, and the "clearance" radius around the previous planet
     * in meters, produces orbit statistics (periapsis, apoapsis, and
     * clearance) in meters.
     *
     * The first planet uses a previous clearance of 0.
     */
    function getPlanetOrbitDimensions(MacroverseStarGenerator.ObjectClass objectClass,
        MacroverseStarGenerator.SpectralType spectralType, bytes32 seed, PlanetClass class, int128 realPrevClearance)
        public view onlyControlledAccess returns (int128 realPeriapsis, int128 realApoapsis, int128 realClearance) {

        // Each object class and spectral type combo has a characteristic base length (in km).
        // For sun-sized TypeG MainSequence stars, that is 1,000,000
        int88 baseLength;
        if (objectClass == MacroverseStarGenerator.ObjectClass.BlackHole) {
            // Black hole systems should be about twice our size
            baseLength = 2000000;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.NeutronStar) {
            // Neutron star systems should be about our size
            baseLength = 1100000;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.WhiteDwarf) {
            // White dwarf systems can be smaller
            baseLength = 800000;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.MainSequence) {
            if (spectralType == MacroverseStarGenerator.SpectralType.TypeO) {
                // Type O systems should be big (10x)
                baseLength = 10000000;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeB) {
                // Type B should be smaller (5x)
                baseLength = 5000000;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeA) {
                // Type A should be just a bit bigger
                baseLength = 1500000;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeF) {
                // Type F should be just a hair bigger
                baseLength = 1200000;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeG) {
                // Type G should be on average our size
                baseLength = 1000000;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeK) {
                // Type K should be smaller (1/3)
                baseLength = 333333;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeM) {
                // Type M should be even smaller (1/10)
                baseLength = 100000;
            } else {
                // Not real!
                revert();
            }
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Giant) {
            // Giants are giant (20x)
            baseLength = 20000000;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Supergiant) {
            // Supergiants are gianter (50x)
            baseLength = 50000000;
        } else {
            // Not real!
            revert();
        }

        int128 realBaseLengthMeters = RealMath.toReal(1000 * baseLength);

        // Make the planet RNG node to use for all the computations
        var node = RNG.RandNode(seed);
        
        // Compute the statistics with their own functions
        realPeriapsis = getPlanetPeriapsis(node, class, realBaseLengthMeters, realPrevClearance);
        realApoapsis = getPlanetApoapsis(node, class, realBaseLengthMeters, realPeriapsis);
        realClearance = getPlanetClearance(node, class, realBaseLengthMeters, realApoapsis);
    }

    /**
     * Decide what the planet's orbit's periapsis is, in meters.
     * This is the first statistic about the orbit to be generated.
     *
     * For the first planet, realPrevClearance is 0. For others, it is the
     * clearance (i.e. distance from star that the planet has cleared out) of
     * the previous planet.
     */
    function getPlanetPeriapsis(RNG.RandNode planetNode, PlanetClass class, int128 realBaseLength, int128 realPrevClearance) internal view returns (int128) {
        
        var node = planetNode.derive("periapsis");
        
        // Define minimum and maximum periapsis distance above previous planet's
        // cleared band in millions of km
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 40;
            maximum = 70;
        } else if (class == PlanetClass.Uranian) {
            minimum = 1000;
            maximum = 2000;
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
        
        int128 realSeparation = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realPrevClearance + RealMath.mul(realSeparation, realBaseLength); 
    }
    
    /**
     * Decide what the planet's orbit's apoapsis is, in meters.
     * This is the second statistic about the orbit to be generated.
     */
    function getPlanetApoapsis(RNG.RandNode planetNode, PlanetClass class, int128 realBaseLength, int128 realPeriapsis) internal view returns (int128) {
        
        var node = planetNode.derive("apoapsis");
        
        // Define minimum and maximum apoapsis distance above planet's periapsis
        // Think in gigameters (millions of km)
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 0;
            maximum = 6;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 0;
            maximum = 10;
        } else if (class == PlanetClass.Uranian) {
            minimum = 20;
            maximum = 1000;
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
        
        int128 realWidth = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realPeriapsis + RealMath.mul(realWidth, realBaseLength); 
    }
    
    /**
     * Decide how far out the cleared band after the planet's orbit is.
     */
    function getPlanetClearance(RNG.RandNode planetNode, PlanetClass class, int128 realBaseLength, int128 realApoapsis) internal view returns (int128) {
        
        var node = planetNode.derive("cleared");
        
        // Define minimum and maximum clearance in millions of km.
        // TODO: Constants should be sort of like the periapsis constants I think? But maybe not identical.
        // Think in gigameters (millions of km)
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 40;
            maximum = 70;
        } else if (class == PlanetClass.Uranian) {
            minimum = 1000;
            maximum = 2000;
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
        
        int128 realSeparation = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realApoapsis + RealMath.mul(realSeparation, realBaseLength); 
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
        if (class == PlanetClass.Lunar) {
            minimum = 0;
            maximum = 175;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 0;
            maximum = 87;
        } else if (class == PlanetClass.Uranian) {
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
        if (node.derive("retrograde").d(1, 100, 0) < 2) {
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
}
 
