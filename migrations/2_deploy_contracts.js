var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseStarGenerator = artifacts.require("./MacroverseStarGenerator.sol")
var MacroverseStarRegistry = artifacts.require("./MacroverseStarRegistry.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")
var UnrestrictedAccessControl = artifacts.require("./UnrestrictedAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  deployer.deploy(RealMath)
  deployer.link(RealMath, RNG)
  deployer.deploy(RNG)
  deployer.link(RNG, MacroverseStarGenerator)
  deployer.link(RealMath, MacroverseStarGenerator)

  deployer.deploy(UnrestrictedAccessControl)
  
  // Deploy the token
  await deployer.deploy(MRVToken, accounts[0]).then(function() {
  
    // Deploy a minimum balance access control strategy, with a 100 MRV minimum balance requirement.
    return deployer.deploy(MinimumBalanceAccessControl, MRVToken.address, web3.toWei(100, "ether")).then(async function() {
      // Deploy the actual MG prototype and point it initially at that access control contract.
      await deployer.deploy(MacroverseStarGenerator, "prototypeseed12", MinimumBalanceAccessControl.address)
      // Deploy the star ownership registry, with a 1000 MRV minimum ownership deposit.
      await deployer.deploy(MacroverseStarRegistry, MRVToken.address, web3.toWei(1000, "ether"))
    })
  })
  
};
