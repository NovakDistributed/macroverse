pragma solidity ^0.4.11;

import "./RealMath.sol";

// TODO: don't just take selfs, use some kind of composite-able slice-based thing to avoid concat-ing.

library RNG {
    using RealMath for *;

    /**
     * We are going to define a RandNode struct to allow for hash chaining.
     * You can extend a RandNode with a bunch of different stuff and get a new RandNode.
     * You can then use a RandNode to get a single, repeatable random value.
     * This eliminates the need for concatenating string selfs, which is a huge pain in Solidity.
     */
    struct RandNode {
        // We hash this together with whatever we're mixing in to get the child hash.
        bytes32 _hash;
    }
    
    // All the functions that touch RandNodes need to be internal.
    // If you want to pass them in and out of contracts just use the bytes32.
    
    // You can get all these functions as methods on RandNodes by "using RNG for *" in your library/contract.
    
    /**
     * Mix string data into a RandNode. Returns a new RandNode.
     */
    function derive(RandNode self, string entropy) internal constant returns (RandNode) {
        // Hash what's there now with the new stuff.
        return RandNode(sha256(self._hash, entropy));
    }
    
    /**
     * Mix signed int data into a RandNode. Returns a new RandNode.
     */
    function derive(RandNode self, int256 entropy) internal constant returns (RandNode) {
        return RandNode(sha256(self._hash, entropy));
    }
    
     /**
     * Mix unsigned int data into a RandNode. Returns a new RandNode.
     */
    function derive(RandNode self, uint256 entropy) internal constant returns (RandNode) {
        return RandNode(sha256(self._hash, entropy));
    }

    /**
     * Returns the base RNG hash for the given RandNode.
     * Does another round of hashing in case you made a RandNode("Stuff").
     */
    function getHash(RandNode self) internal constant returns (bytes32) {
        return sha256(self._hash);
    }
    
    /**
     * Return true or false with 50% probability.
     */
    function getBool(RandNode self) internal constant returns (bool) {
        return getHash(self) & 0x1 > 0;
    }
    
    /**
     * Get an int128 full of random bits.
     */
    function getInt128(RandNode self) internal constant returns (int128) {
        // Just cast to int and truncate
        return int128(int256(getHash(self)));
    }
    
    /**
     * Get a real88x40 between 0 (inclusive) and 1 (exclusive).
     */
    function getReal(RandNode self) internal constant returns (int128) {
        return getInt128(self).fpart();
    }
    
    /**
     * Get an integer between low, inclusive, and high, exclusive. Represented as a normal int, not a real.
     */
    function getIntBetween(RandNode self, int88 low, int88 high) internal constant returns (int88) {
        return RealMath.fromReal((getReal(self).mul(RealMath.toReal(high) - RealMath.toReal(low))) + RealMath.toReal(low));
    }
    
    /**
     * Roll a number of die of the given size, add/subtract a bonus, and return the result.
     * Max size is 100.
     */
    function d(RandNode self, int8 count, int8 size, int8 bonus) internal constant returns (int16) {
        if (count == 1) {
            // Base case
            return int16(getIntBetween(self, 1, size)) + bonus;
        } else {
            // Loop and sum
            int16 sum = bonus;
            for(int8 i = 0; i < count; i++) {
                // Roll each die with no bonus
                sum += d(derive(self, i), 1, size, 0);
            }
            return sum;
        }
    }
}

