var MacroverseStarRegistry = artifacts.require("./MacroverseStarRegistry.sol")

module.exports = async function(deployer, network, accounts) {

  let instance = await MacroverseStarRegistry.deployed() 
  
  // The all-1s uint256 didn't work here, so settle for a number that is merely
  // larger than the number of MRV actually in existence.
  return instance.setMinimumDeposit(web3.toWei(999999999999, "ether"))
  
};
