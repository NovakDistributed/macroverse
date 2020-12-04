var MacroverseUniversalRegistry = artifacts.require("./MacroverseUniversalRegistry.sol")
var MacroverseRealEstate = artifacts.require("./MacroverseRealEstate.sol")

// new Truffle doesn't give us free toWei
const Web3Utils = require('web3-utils')

module.exports = async function(deployer, network, accounts) {

  let reg = await MacroverseUniversalRegistry.deployed()
  let real = await MacroverseRealEstate.deployed()
  
  // Take back the real estate token from the registry
  return reg.reclaimContract(real.address)
  
};
