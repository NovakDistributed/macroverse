pragma solidity ^0.4.18;

import "./RealMath.sol";

/**
 * Provides methods for doing orbital mechanics calculations, based on RealMath.
 */
contract OrbitalMechanics {
    using RealMath for *;

    /**
     * We need the gravitational constant. Calculated by solving the mean
     * motion equation for Earth. We can be mostly precise here, because we
     * know the semimajor axis and year length (in Julian years) to a few
     * places.
     */
    int128 constant REAL_G_PER_SOL = 145919349250077040774785972305920;

    // TODO: We have to copy-paste constants from RealMath because Solidity doesn't expose them by import.

    /**
     * It is also useful to have Pi around.
     * We can't pull it in from the library.
     */
    int128 constant REAL_PI = 3454217652358;

    /**
     * And two pi, which happens to be odd in its most accurate representation.
     */
    int128 constant REAL_TWO_PI = 6908435304715;

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
     * We need 2 for constants in numerical methods.
     */
    int128 constant REAL_TWO = REAL_ONE * 2;
    
    /**
     * We need 3 for constants in numerical methods.
     */
    int128 constant REAL_THREE = REAL_ONE * 3;

    /**
     * A "year" is 365.25 days. We use Julian years.
     */
    int128 constant REAL_SECONDS_PER_YEAR = 34697948144703898000;

    

    // Functions for orbital mechanics. Maybe should be a library?
    // Are NOT controlled access, since they don't talk to the RNG.
    // Please don't do these in Solidity unless you have to; you can do orbital mechanics in JS just fine with actual floats.
    // The steps to compute an orbit are:
    // 
    // 1. Compute the semimajor axis as (apoapsis + periapsis) / 2 (do this yourself)
    // 2. Compute the mean angular motion, n = sqrt(central mass * gravitational constant / semimajor axis^3)
    // 3. Compute the Mean Anomaly, as n * time since epoch + MA at epoch, and wrap to an angle 0 to 2 pi
    // 4. Compute the Eccentric Anomaly numerically to solve MA = EA - eccentricity * sin(EA)
    // 5. Compute the True Anomaly as 2 * atan2(sqrt((1 + eccentricity) / (1 - eccentricity)) * tan(EA/2))
    // 6. Compute the current radius as r = semimajor * (1 - eccentricity^2) / (1 + eccentricity * cos(TA))
    // 7. Compute Cartesian X (toward longitude 0) = radius * (cos(LAN) * cos(AOP + TA) - sin(LAN) * sin(AOP + TA) * cos(inclination))
    // 8. Compute Cartesian Y (in plane) = radius * (sin(LAN) * cos(AOP + TA) + cos(LAN) * sin(AOP + TA) * cos(inclination))
    // 9. Compute Cartesian Z (above plane) = radius * sin(inclination) * sin(AOP + TA)


    /**
     * Compute the mean angular motion, in radians per Julian year (365.25
     * days), given a star mass in sols and a semimajor axis in meters.
     */
    function computeMeanAngularMotion(int128 real_central_mass_in_sols, int128 real_semimajor_axis) public pure returns (int128) {
        // REAL_G_PER_SOL is big, but nothing masses more than 100s of sols, so we can do the multiply.
        // But the semimajor axis in meters may be very big so we can't really do the cube for the denominator.
        // And since values in radians per second are tiny, their squares are even tinier and probably out of range.
        // So we scale up to radians per year
        return real_central_mass_in_sols.mul(REAL_G_PER_SOL)
            .div(real_semimajor_axis)
            .mul(REAL_SECONDS_PER_YEAR)
            .div(real_semimajor_axis)
            .mul(REAL_SECONDS_PER_YEAR).div(real_semimajor_axis).sqrt();
    }

    /**
     * Compute the mean anomaly, from 0 to 2 PI, given the mean anomaly at
     * epoch, mean angular motion (in radians per Julian year) and the time (in
     * Julian years) since epoch.
     */
    function computeMeanAnomaly(int128 real_mean_anomaly_at_epoch, int128 real_mean_angular_motion, int128 real_years_since_epoch) public pure returns (int128) {
        return (real_mean_anomaly_at_epoch + real_mean_angular_motion.mul(real_years_since_epoch)) % REAL_TWO_PI;
    }

    /**
     * Compute the eccentric anomaly, given the mean anomaly and eccentricity.
     * Uses numerical methods to solve MA = EA - eccentricity * sin(EA). Limit to a certain iteration count.
     */
    function computeEccentricAnomalyLimited(int128 real_mean_anomaly, int128 real_eccentricity, int88 max_iterations) public pure returns (int128) {
        // We are going to find the root of EA - eccentricity * sin(EA) - MA, in EA.
        // We use Newton's Method.
        // f(EA) =  EA - eccentricity * sin(EA) - MA
        // f'(EA) = 1 - eccentricity * cos(EA)
        // x_n = x_n-1 - f(x_n) / f'(x_n)

        // Start with the 3rd-order approximation from http://alpheratz.net/dynamics/twobody/KeplerIterations_summary.pdf

        int128 e2 = real_eccentricity.mul(real_eccentricity);
        int128 e3 = e2.mul(real_eccentricity);
        int128 cosMA = real_mean_anomaly.cos();
        int128 real_guess = real_mean_anomaly + ((-REAL_HALF).mul(e3) + real_eccentricity + 
            (e2 + cosMA.mul(e3).mul(REAL_THREE).div(REAL_TWO)).mul(cosMA)).mul(real_mean_anomaly.sin());
            
        for (int88 i = 0; i < max_iterations; i++) {
            int128 real_value = real_guess - real_eccentricity.mul(real_guess.sin()) - real_mean_anomaly;
            
            if (real_value.abs() <= 5) {
                // We found the root within epsilon.
                // Note that we are implicitly turning this random small number into a tiny real.
                break;
            }
            
            // Otherwise we update
            int128 real_derivative = REAL_ONE - real_eccentricity.mul(real_guess.cos());
            // The derivative can never be 0. If it were, since cos() is <= 1, the eccentricity would be 1.
            // Eccentricity must be <= 1
            assert(real_derivative != 0);
            real_guess = real_guess - real_value.div(real_derivative);
        }

        // Bound to 0 to 2 pi angle range.
        return real_guess % REAL_TWO_PI;
    }

    /**
     * Compute the eccentric anomaly, given the mean anomaly and eccentricity.
     * Uses numerical methods to solve MA = EA - eccentricity * sin(EA). Internally limited to a reasonable iteration count.
     */
    function computeEccentricAnomaly(int128 real_mean_anomaly, int128 real_eccentricity) public pure returns (int128) {
        return computeEccentricAnomalyLimited(real_mean_anomaly, real_eccentricity, 10);
    }
    
}
