var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseSystemGenerator = artifacts.require("./MacroverseSystemGenerator.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RNG, MacroverseSystemGenerator)
  deployer.link(RealMath, MacroverseSystemGenerator)

  // And deploy the system generator, using the existing access control.
  await deployer.deploy(MacroverseSystemGenerator, MinimumBalanceAccessControl.address)
      
  
};
