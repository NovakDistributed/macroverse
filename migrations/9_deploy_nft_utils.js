var MacroverseNFTUtils = artifacts.require("./MacroverseNFTUtils.sol")

module.exports = async function(deployer, network, accounts) {

  return deployer.deploy(MacroverseNFTUtils)
  
};
