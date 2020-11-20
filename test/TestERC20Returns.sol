pragma solidity ^0.6.10;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";

// The real ERC20 standard has approve, transfer, and transferFrom returning bools, but the
// OpenZeppelin implementation that was used for the MRV token just has them throw/not throw.
// It's recommented for an ERC20 token to throw when it would return false, so we just have
// to make sure that when it doesn't throw that's the same to callers expecting the
// standard-compliant ABI as having returned true.

abstract contract FakeERC20 {
    function totalSupply() virtual public view returns (uint totalSupplyOut);
    function balanceOf(address _owner) virtual public view returns (uint balance);
    function transfer(address _to, uint _value) virtual public;
    function transferFrom(address _from, address _to, uint _value) virtual public;
    function approve(address _spender, uint _value) virtual public;
    function allowance(address _owner, address _spender) virtual public view returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

abstract contract RealERC20 {
    function totalSupply() virtual public view returns (uint totalSupplyOut);
    function balanceOf(address _owner)  virtual public view returns (uint balance);
    function transfer(address _to, uint _value) virtual public returns (bool success);
    function transferFrom(address _from, address _to, uint _value) virtual public returns (bool success);
    function approve(address _spender, uint _value)  virtual public returns (bool success);
    function allowance(address _owner, address _spender)  virtual public view returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract SuccessCoin is FakeERC20 {
    function totalSupply() override public view returns (uint totalSupplyOut) {
        return 99999;
    }
    function transfer(address to, uint value) override public {
        // Say it worked by not throwing
    }
    function transferFrom(address from, address to, uint value) override public {
        // Say it worked by not throwing
    }
    function approve(address spender, uint value) override public {
        // Say it worked by not throwing
    }
    function balanceOf(address /*who*/) override public view returns (uint) {
        return 99999;
    }
    function allowance(address /*owner*/, address /*spender*/) override public view returns (uint) {
        return 99999;
    }
}

contract TestERC20Returns {

    function testTransferSuccessReturnsTrue() public {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.transfer(tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.transfer(address(0), 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
    function testTransferFromSuccessReturnsTrue() public {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.transferFrom(address(this), tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.transferFrom(address(0), address(0), 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
     function testApproveSuccessReturnsTrue() public {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.approve(tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.approve(address(0), 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
}

// SPDX-License-Identifier: UNLICENSED

