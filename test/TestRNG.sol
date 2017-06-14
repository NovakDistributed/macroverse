pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RNG.sol";

contract TestRNG {
    using RNG for *;
    
    function testGetReal() {
        var root = RNG.RandNode("root");
        for (uint i = 0; i < 100; i++) {
            var key = root.derive(i);
            var generated = key.getReal();
            Assert.isAtMost(generated, RealMath.toReal(1), "Generated fractional values are <=1");
            Assert.isAtLeast(generated, RealMath.toReal(0), "Generated fractional values are >=0");
        }
    }
    
    function testGetIntBetween() {
        var root = RNG.RandNode("root");
        for (uint i = 0; i < 100; i++) {
            var key = root.derive(i);
            var generated = key.getIntBetween(1, 11);
            Assert.isAtMost(generated, 10, "Generated ints are less than high");
            Assert.isAtLeast(generated, 1, "Generated ints are at least low");
        }
    }
}
