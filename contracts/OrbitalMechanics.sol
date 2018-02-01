pragma solidity ^0.4.18;

import "./RealMath.sol";

/**
 * Provides methods for doing orbital mechanics calculations, based on RealMath.
 */
contract OrbitalMechanics {
    using RealMath for *;

    /**
     * We need the gravitational constant
     * G = 1.32754125 * 10^20 m^3 / s^2 / solar mass
     * We can't really measure G that accurately but we need a number for any orbiting to happen.
     */
    int128 constant REAL_G_PER_SOL = 145964704072728570000000000000000;

    /**
     * It is also useful to have Pi around.
     * We can't pull it in from the library.
     */
    int128 constant REAL_PI = 3454217652358;


    // Functions for orbital mechanics. Maybe should be a library?
    // Are NOT controlled access, since they don't talk to the RNG.
    // Please don't do these in Solidity unless you have to; you can do orbital mechanics in JS just fine with actual floats.
    // The steps to compute an orbit are:
    // 
    // 1. Compute the mean angular motion, n = sqrt(central mass * gravitational constant / semimajor axis^3)
    // 2. Compute the Mean Anomaly, as n * time since epoch, and wrap to an angle 0 to 2 pi
    // 3. Compute the Eccentric Anomaly numerically to solve MA = EA - eccentricity * sin(ea)
    // 4. Compute the True Anomaly as 2 * atan2(sqrt((1 + eccentricity) / (1 - eccentricity)) * tan(EA/2))
    // 5. Compute the current radius as r = semimajor * (1 - eccentricity^2) / (1 + eccentricity * cos(TA))
    // 6. Compute Cartesian X (toward longitude 0) = radius * (cos(LAN) * cos(AOP + TA) - sin(LAN) * sin(AOP + TA) * cos(inclination))
    // 7. Compute Cartesian Y (in plane) = radius * (sin(LAN) * cos(AOP + TA) + cos(LAN) * sin(AOP + TA) * cos(inclination))
    // 8. Compute Cartesian Z (above plane) = radius * sin(inclination) * sin(AOP + TA)


    /**
     * Compute the mean angular motion, in radians per year, given a star mass in sols and a semimajor axis in meters.
     */
    function computeMeanAngularMotion(int128 real_central_mass_in_sols, int128 real_semimajor_axis) public pure returns (int128) {
        // REAL_G_PER_SOL is big, but nothing masses more than 100s of sols, so we can do the multiply.
        // But the semimajor axis in meters may be very big so we can't really do the cube for the denominator.
        // And since values in radians per second are tiny, their squares are even tinier and probably out of range.
        // So we scale up to radians per year by mixing in multiplies by 31536000
        return real_central_mass_in_sols.mul(REAL_G_PER_SOL).div(real_semimajor_axis)
            .mul(RealMath.toReal(31536000)).div(real_semimajor_axis)
            .mul(RealMath.toReal(31536000)).div(real_semimajor_axis).sqrt();
    }
    
}
