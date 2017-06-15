var RealMath = artifacts.require("./RealMath.sol");
var RNG = artifacts.require("./RNG.sol");
var MacroversePrototype = artifacts.require("./MacroversePrototype.sol")

var MRVToken = artifacts.require("./MRVToken.sol")

module.exports = function(deployer, network, accounts) {
  deployer.deploy(RealMath);
  deployer.link(RealMath, RNG);
  deployer.deploy(RNG);
  deployer.link(RNG, MacroversePrototype);
  deployer.link(RealMath, MacroversePrototype);
  deployer.deploy(MacroversePrototype, "prototypeseed12");
  
  // Now the crowdsale stuff
  deployer.deploy(MRVToken, accounts[0]);
  
};
