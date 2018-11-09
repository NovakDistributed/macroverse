var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseStarGeneratorPatch1 = artifacts.require("./MacroverseStarGeneratorPatch1.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RNG, MacroverseStarGeneratorPatch1)
  deployer.link(RealMath, MacroverseStarGeneratorPatch1)

  // And deploy the star generator patch contract, using the existing access control.
  await deployer.deploy(MacroverseStarGeneratorPatch1, MinimumBalanceAccessControl.address)
      
  
};
