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
    
    function testD() {
        var root = RNG.RandNode("root");
        for (uint i = 0; i < 100; i++) {
            var key = root.derive(i);
            var generated = key.d(2, 8, 3);
            Assert.isAtMost(generated, 19, "2d8+3 maxes out at 19");
            Assert.isAtLeast(generated, 5, "2d8+3 is no less than 5");
        }
    }
}
