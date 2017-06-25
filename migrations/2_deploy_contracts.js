var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseStarGenerator = artifacts.require("./MacroverseStarGenerator.sol")
var MacroverseStarRegistry = artifacts.require("./MacroverseStarRegistry.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")
var UnrestrictedAccessControl = artifacts.require("./UnrestrictedAccessControl.sol")

var LIVE_BENEFICIARY="0x2fe5bdc68d73b1f570b97422021a0c9cdccae79f"
var LIVE_TOKEN_ACCOUNT="0x368651F6c2b3a7174ac30A5A062b65F2342Fb6F1"

module.exports = async function(deployer, network, accounts) {
  deployer.deploy(RealMath)
  deployer.link(RealMath, RNG)
  deployer.deploy(RNG)
  deployer.link(RNG, MacroverseStarGenerator)
  deployer.link(RealMath, MacroverseStarGenerator)

  // Figure out where crowdsale proceeds belong
  let beneficiary = (network == "live" ? LIVE_BENEFICIARY : accounts[0])
  // And the reserved tokens
  let tokenAccount = (network == "live" ? LIVE_TOKEN_ACCOUNT : accounts[0])
  
  console.log("On network " + network + " and sending ETH to " + beneficiary + " and MRV to " + tokenAccount)
  
  deployer.deploy(UnrestrictedAccessControl)
  
  // Deploy the token
  await deployer.deploy(MRVToken, beneficiary, tokenAccount).then(function() {

    // Deploy a minimum balance access control strategy, with a 100 MRV minimum balance requirement.
    return deployer.deploy(MinimumBalanceAccessControl, MRVToken.address, web3.toWei(100, "ether")).then(async function() {
      // Deploy the actual MG prototype and point it initially at that access control contract.
      await deployer.deploy(MacroverseStarGenerator, "FiatBlocks", MinimumBalanceAccessControl.address)
      // Deploy the star ownership registry, with a 1000 MRV minimum ownership deposit.
      await deployer.deploy(MacroverseStarRegistry, MRVToken.address, web3.toWei(1000, "ether"))
    })
  })
  
};
