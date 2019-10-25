var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseStarGenerator = artifacts.require("./MacroverseStarGenerator.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RNG, MacroverseStarGenerator)
  deployer.link(RealMath, MacroverseStarGenerator)

  // And deploy updated MacroverseStarGenerator with original parameters but new code.
  await deployer.deploy(MacroverseStarGenerator, "0x46696174426c6f636b73", MinimumBalanceAccessControl.address)
      
  
};
