var MRVToken = artifacts.require("./MRVToken.sol")
var TestnetMRVToken = artifacts.require("./TestnetMRVToken.sol")
var MacroverseNFTUtils = artifacts.require("./MacroverseNFTUtils.sol")
var MacroverseExistenceChecker = artifacts.require("./MacroverseExistenceChecker.sol")
var MacroverseUniversalRegistry = artifacts.require("./MacroverseUniversalRegistry.sol")
var MacroverseRealEstate = artifacts.require("./MacroverseRealEstate.sol")

// new Truffle doesn't give us free toWei
const Web3Utils = require('web3-utils')

module.exports = async function(deployer, network, accounts) {

  deployer.link(MacroverseNFTUtils, MacroverseUniversalRegistry)

  // Determine the token to use for the registry
  // On testnet we use one that lets anyone mint tokens for free
  // This has to pick the same contract we deployed in 2_deploy_contracts.js,
  // so it should match the code there.
  let token_contract = (network.startsWith("rinkeby") ? TestnetMRVToken : MRVToken)
  
  // Use the existing real estate token
  let backend = await MacroverseRealEstate.deployed() 
  
  // Deploy a new frontend
  return deployer.deploy(MacroverseUniversalRegistry, MacroverseRealEstate.address,
    MacroverseExistenceChecker.address, token_contract.address, 
    Web3Utils.toWei("1000", "ether"), 5 * 60).then(function() {
    
    return MacroverseRealEstate.deployed() 
  }).then(function(backend) {
    // Give the backend to the frontend
    return backend.transferOwnership(MacroverseUniversalRegistry.address)
  })
  
  
  
};
