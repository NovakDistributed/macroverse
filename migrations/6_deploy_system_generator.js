var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var Macroverse = artifacts.require("./Macroverse.sol")
var MacroverseSystemGeneratorPart1 = artifacts.require("./MacroverseSystemGeneratorPart1.sol")
var MacroverseSystemGeneratorPart2 = artifacts.require("./MacroverseSystemGeneratorPart2.sol")
var MacroverseSystemGenerator = artifacts.require("./MacroverseSystemGenerator.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")

module.exports = function(deployer, network, accounts) {
  return deployer.deploy(Macroverse).then(function() {
    // Link
    deployer.link(RNG, MacroverseSystemGeneratorPart1)
    deployer.link(RealMath, MacroverseSystemGeneratorPart1)

    deployer.link(RNG, MacroverseSystemGeneratorPart2)
    deployer.link(RealMath, MacroverseSystemGeneratorPart2)

    return deployer.deploy(MacroverseSystemGeneratorPart1)
  }).then(function() {
    return deployer.deploy(MacroverseSystemGeneratorPart2)
  }).then(function() {
    deployer.link(MacroverseSystemGeneratorPart1, MacroverseSystemGenerator)
    deployer.link(MacroverseSystemGeneratorPart2, MacroverseSystemGenerator)
    
    // And deploy the system generator, using the existing access control.
    return deployer.deploy(MacroverseSystemGenerator, MinimumBalanceAccessControl.address)
  })
};
