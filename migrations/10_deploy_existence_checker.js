var MacroverseStarGenerator = artifacts.require("./MacroverseStarGenerator.sol")
var MacroverseStarGeneratorPatch1 = artifacts.require("./MacroverseStarGeneratorPatch1.sol")
var MacroverseSystemGenerator = artifacts.require("./MacroverseSystemGenerator.sol")
var MacroverseMoonGenerator = artifacts.require("./MacroverseMoonGenerator.sol")
var MacroverseNFTUtils = artifacts.require("./MacroverseNFTUtils.sol")
var MacroverseExistenceChecker = artifacts.require("./MacroverseExistenceChecker.sol")

module.exports = async function(deployer, network, accounts) {

  deployer.link(MacroverseNFTUtils, MacroverseExistenceChecker)

  // Deploy the existence checker. 
  return deployer.deploy(MacroverseExistenceChecker, MacroverseStarGenerator.address,
    MacroverseStarGeneratorPatch1.address, MacroverseSystemGenerator.address, MacroverseMoonGenerator.address)
  
};
