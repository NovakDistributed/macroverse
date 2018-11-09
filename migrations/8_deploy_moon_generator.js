var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseMoonGenerator = artifacts.require("./MacroverseMoonGenerator.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RNG, MacroverseMoonGenerator)
  deployer.link(RealMath, MacroverseMoonGenerator)

  // And deploy the moon generator, using the existing access control.
  await deployer.deploy(MacroverseMoonGenerator, MinimumBalanceAccessControl.address)
      
  
};
