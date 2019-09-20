var MRVToken = artifacts.require("./MRVToken.sol")
var TestnetMRVToken = artifacts.require("./TestnetMRVToken.sol")
var MacroverseNFTUtils = artifacts.require("./MacroverseNFTUtils.sol")
var MacroverseExistenceChecker = artifacts.require("./MacroverseExistenceChecker.sol")
var MacroverseUniversalRegistry = artifacts.require("./MacroverseUniversalRegistry.sol")

module.exports = async function(deployer, network, accounts) {

  deployer.link(MacroverseNFTUtils, MacroverseUniversalRegistry)

  // Determine the token to use for the registry
  // On testnet we use one that lets anyone mint tokens for free
  let token_contract = (network == "rinkeby_infura" ? TestnetMRVToken : MRVToken)

  // Deploy the registry, using the existence checker and the existing token
  // and a starting min star deposit, with a 1 day commitment maturation time.
  return deployer.deploy(MacroverseUniversalRegistry, MacroverseExistenceChecker.address,
    token_contract.address, web3.toWei(1000, "ether"), 60 * 60 * 24)
  
};
