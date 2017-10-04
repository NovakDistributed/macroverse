pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "zeppelin-solidity/contracts/token/ERC20.sol";

// The real ERC20 standard has approve, transfer, and transferFrom returning bools, but the
// OpenZeppelin implementation just has them throw/not throw.
// It's recommented for an ERC20 token to throw when it would return false, so we just have
// to make sure that when it doesn't throw that's the same to callers expecting the
// standard-compliant ABI as having returned true.

contract RealERC20 {
    function totalSupply() constant returns (uint totalSupply);
    function balanceOf(address _owner) constant returns (uint balance);
    function transfer(address _to, uint _value) returns (bool success);
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
    function approve(address _spender, uint _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract SuccessCoin is ERC20 {
    function transfer(address to, uint value) {
        // Say it worked by not throwing
    }
    function transferFrom(address from, address to, uint value) {
        // Say it worked by not throwing
    }
    function approve(address spender, uint value) {
        // Say it worked by not throwing
    }
    function balanceOf(address who) constant returns (uint) {
        return 99999;
    }
    function allowance(address owner, address spender) constant returns (uint) {
        return 99999;
    }
}

contract TestERC20Returns {

    function testTransferSuccessReturnsTrue() {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.transfer(tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.transfer(0, 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
    function testTransferFromSuccessReturnsTrue() {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.transferFrom(this, tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.transferFrom(0, 0, 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
     function testApproveSuccessReturnsTrue() {
        SuccessCoin success = new SuccessCoin();

        RealERC20 wrapped = RealERC20(address(success));
        
        Assert.equal(wrapped.approve(tx.origin, 100), true, "Not throwing is interpreted as returning true");
        Assert.equal(wrapped.approve(0, 0), true, "Not throwing is interpreted as returning true even when all arguments are zero");
    }
    
}
