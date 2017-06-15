var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroversePrototype = artifacts.require("./MacroversePrototype.sol")

var MRVToken = artifacts.require("./MRVToken.sol")
var MacroverseCouncil = artifacts.require("./MacroverseCouncil.sol")

module.exports = function(deployer, network, accounts) {
  deployer.deploy(RealMath)
  deployer.link(RealMath, RNG)
  deployer.deploy(RNG)
  deployer.link(RNG, MacroversePrototype)
  deployer.link(RealMath, MacroversePrototype)
  deployer.deploy(MacroversePrototype, "prototypeseed12")
  
  // Now the crowdsale stuff
  
  // Deploy the token
  deployer.deploy(MRVToken, accounts[0]).then(function() {
  
    // Deploy the DAO, with the MRV token as shares, 5000 needed for quorum, and 14 days for debate on proposals.
    deployer.deploy(MacroverseCouncil, MRVToken.address, 5000, 14 * 24 * 60)
  })
  
};
