var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroversePrototype = artifacts.require("./MacroversePrototype.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = function(deployer, network, accounts) {
  deployer.deploy(RealMath)
  deployer.link(RealMath, RNG)
  deployer.deploy(RNG)
  deployer.link(RNG, MacroversePrototype)
  deployer.link(RealMath, MacroversePrototype)
  deployer.deploy(MacroversePrototype, "prototypeseed12")
  
  // Now the crowdsale stuff
  
  // Deploy the token
  deployer.deploy(MRVToken, accounts[0]).then(function() {
  
    // Deploy a minimum balance access control strategy
    deployer.deploy(MinimumBalanceAccessControl, MRVToken.address, 5000).then(function() {
      // Deploy the actual MG prototype and point it initially at that access control contract.
    })
  })
  
};
