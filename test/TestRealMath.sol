pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RealMath.sol";

contract TestRealMath {
    function testConstructionFromInt() public {
        Assert.equal(RealMath.toReal(0x12345), 0x123450000000000, "Integer part should be placed in the right bits");
    }
    
    function testConversionToInt() public {
        Assert.equal(RealMath.fromReal(0x123456789000000), 0x12345, "Integer part should be extracted from the right bits");
    }
    
    function testMultiplication() public {
        Assert.equal(RealMath.fromReal(RealMath.mul(RealMath.toReal(123), RealMath.toReal(456))), 123 * 456, "Integer multiplication should work");
    }
    
    function testDivision() public {
        Assert.equal(RealMath.div(RealMath.toReal(72), RealMath.toReal(6)), RealMath.toReal(12), "Integer division should work");
    }
    
    function testFractional() public {
        int128 third = RealMath.div(RealMath.toReal(1), RealMath.toReal(3));
        
        Assert.equal(RealMath.round(RealMath.mul(third, RealMath.toReal(15))), RealMath.toReal(5), "Division to and multiplication by fractions should work");
    }
    
    function testAbs() public {
        Assert.equal(RealMath.abs(RealMath.toReal(-10)), RealMath.toReal(10), "Absolute value pos-ifies negative numbers");
    }
    
    function testFpart() public {
        int128 fourThirds = RealMath.div(RealMath.toReal(4), RealMath.toReal(3));
        int128 third = RealMath.div(RealMath.toReal(1), RealMath.toReal(3));
        
        Assert.equal(RealMath.fpart(fourThirds), third, "Getting the fractional part should work");
        
        Assert.equal(RealMath.fpart(-third), third, "Sign is ignored by fpart");
    }
}
