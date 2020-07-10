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

  // Deploy the registry, using the existence checker and the existing token
  // and a starting min star deposit, with a 5 minute commitment maturation time.
  // Buying out the whole network as of this writing costs ~$11.82 per block,
  // with ~15 seconds per block, so this gives us an attack cost of ~$236.40,
  // which is more than stealing someone's virtual real estate out from under
  // them ought to be worth, when you could have just claimed it before. Plus,
  // for extra security, a legit reveal can use a higher gas price, which an
  // attacker has to beat for several blocks.
  return deployer.deploy(MacroverseRealEstate).then(function() {
    return deployer.deploy(MacroverseUniversalRegistry, MacroverseRealEstate.address,
      MacroverseExistenceChecker.address, token_contract.address, 
      Web3Utils.toWei("1000", "ether"), 5 * 60)
  }).then(function() {
    return MacroverseRealEstate.deployed() 
  }).then(function(backend) {
    // Give the backend to the frontend
    return backend.transferOwnership(MacroverseUniversalRegistry.address)
  })
  
  
  
};
