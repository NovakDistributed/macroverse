var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroversePrototype = artifacts.require("./MacroversePrototype.sol")
var MacroverseStarRegistry = artifacts.require("./MacroverseStarRegistry.sol")
var SingleStarPrototype = artifacts.require("./SingleStarPrototype.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")
var UnrestrictedAccessControl = artifacts.require("./UnrestrictedAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  deployer.deploy(RealMath)
  deployer.link(RealMath, RNG)
  deployer.deploy(RNG)
  deployer.link(RNG, MacroversePrototype)
  deployer.link(RealMath, MacroversePrototype)
  deployer.link(RNG, SingleStarPrototype)
  deployer.link(RealMath, SingleStarPrototype)

  deployer.deploy(UnrestrictedAccessControl)
  
  // Deploy the token
  await deployer.deploy(MRVToken, accounts[0]).then(function() {
  
    // Deploy a minimum balance access control strategy
    return deployer.deploy(MinimumBalanceAccessControl, MRVToken.address, web3.toWei(100, "ether")).then(async function() {
      // Deploy the actual MG prototypes and point them initially at that access control contract.
      await deployer.deploy(MacroversePrototype, "prototypeseed12", MinimumBalanceAccessControl.address)
      await deployer.deploy(SingleStarPrototype, "prototypeseed12", MinimumBalanceAccessControl.address)
      
    })
  })
  
};
