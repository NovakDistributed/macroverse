pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RNG.sol";
import "../contracts/deps/StringLib.sol";
import "../contracts/deps/strings.sol";


contract TestRNG {
    // Add methods on strings
    using strings for *;
    
    function testGetReal() {
        for (uint i = 0; i < 100; i++) {
            var key = "test/".toSlice().concat(StringLib.uintToBytes(i).toSliceB32()); 
            var generated = RNG.getReal(key);
            Assert.isAtMost(generated, RealMath.toReal(1), "Generated fractional values are <=1");
            Assert.isAtLeast(generated, RealMath.toReal(0), "Generated fractional values are >=0");
        }
    }
    
    function testGetIntBetween() {
        for (uint i = 0; i < 100; i++) {
            var key = "test/".toSlice().concat(StringLib.uintToBytes(i).toSliceB32()); 
            var generated = RNG.getIntBetween(key, 1, 11);
            Assert.isAtMost(generated, 10, "Generated ints are less than high");
            Assert.isAtLeast(generated, 1, "Generated ints are at least low");
        }
    }
}
