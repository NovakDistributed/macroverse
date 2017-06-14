pragma solidity ^0.4.11;

import "./RealMath.sol";

// TODO: don't just take keys, use some kind of composite-able slice-based thing to avoid concat-ing.

library RNG {
    using RealMath for *;

    /**
     * Returns the base RNG hash for the given key.
     */
    function getHash(string key) constant returns (bytes32) {
        return sha256(key);
    }
    
    /**
     * Return true or false with 50% probability.
     */
    function getBool(string key) constant returns (bool) {
        return getHash(key) & 0x1 > 0;
    }
    
    /**
     * Get an int128 full of random bits.
     */
    function getInt128(string key) constant returns (int128) {
        // Just cast to int and truncate
        return int128(int256(getHash(key)));
    }
    
    /**
     * Get a real88x40 between 0 (inclusive) and 1 (exclusive).
     */
    function getReal(string key) constant returns (int128) {
        return getInt128(key).fpart();
    }
    
    /**
     * Get an integer between low, inclusive, and high, exclusive. Represented as a normal int, not a real.
     */
    function getIntBetween(string key, int88 low, int88 high) constant returns (int88) {
        return RealMath.fromReal((getReal(key).mul(RealMath.toReal(high) - RealMath.toReal(low))) + RealMath.toReal(low));
    }
}

