var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroverseStarGenerator = artifacts.require("./MacroverseStarGenerator.sol")
var MacroverseStarRegistry = artifacts.require("./MacroverseStarRegistry.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var TestnetMRVToken = artifacts.require("./TestnetMRVToken.sol")
var MinimumBalanceAccessControl = artifacts.require("./MinimumBalanceAccessControl.sol")
var UnrestrictedAccessControl = artifacts.require("./UnrestrictedAccessControl.sol")

// new Truffle doesn't give us free toWei
const Web3Utils = require('web3-utils')

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

  // Determine the token to use.
  // On testnet we want to launch one that lets anyone mint tokens for free
  // Make sure to check startsWith to match the -fork network Truffle dry runs the migrations against.
  // TODO: Tests get upset if they try and test MRVToken but TestnetMRVToken was deployed instead.
  let token_contract = (network.startsWith("rinkeby_infura") ? TestnetMRVToken : MRVToken)
  
  // Deploy the token
  await deployer.deploy(token_contract, beneficiary, tokenAccount).then(function() {

    // Deploy a minimum balance access control strategy, with a 100 MRV minimum balance requirement.
    return deployer.deploy(MinimumBalanceAccessControl, token_contract.address, Web3Utils.toWei("100", "ether")).then(async function() {
      // Deploy the actual MG prototype and point it initially at that access control contract.
      // New Truffle no longer lets a string just become bytes32 if not hex.
      await deployer.deploy(MacroverseStarGenerator, "0x46696174426c6f636b73", MinimumBalanceAccessControl.address)
      // Deploy the star ownership registry, with a 1000 MRV minimum ownership deposit.
      await deployer.deploy(MacroverseStarRegistry, token_contract.address, Web3Utils.toWei("1000", "ether"))
    })
  })
  
};
