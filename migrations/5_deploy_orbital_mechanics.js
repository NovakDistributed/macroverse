var RealMath = artifacts.require("./RealMath.sol");
var OrbitalMechanics = artifacts.require("./OrbitalMechanics.sol")

module.exports = async function(deployer, network, accounts) {
  
  // Link
  deployer.link(RealMath, OrbitalMechanics)

  // And deploy the orbital mechanics code
  await deployer.deploy(OrbitalMechanics)
      
  
};
