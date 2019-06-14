var MRVToken = artifacts.require("./MRVToken.sol")

var MacroverseNFTUtils = artifacts.require("./MacroverseNFTUtils.sol")
var MacroverseUniversalRegistry = artifacts.require("./MacroverseUniversalRegistry.sol")

module.exports = async function(deployer, network, accounts) {

  deployer.deploy(MacroverseNFTUtils).then(() => {

    deployer.link(MacroverseNFTUtils, MacroverseUniversalRegistry)

    // Deploy the registry, using the existing token and a starting min star deposit, with a 1 day commitment maturation time.
    return deployer.deploy(MacroverseUniversalRegistry, MRVToken.address, web3.toWei(1000, "ether"), 60 * 60 * 24)
  })
  
};
