var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseTerrainGenerator = artifacts.require("./MacroverseTerrainGenerator.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RNG, MacroverseTerrainGenerator)
  deployer.link(RealMath, MacroverseTerrainGenerator)

  // And deploy the terrain generator, using the existing access control.
  await deployer.deploy(MacroverseTerrainGenerator, MinimumBalanceAccessControl.address)
      
  
};
