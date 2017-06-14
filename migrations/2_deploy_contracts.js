var RNG = artifacts.require("./RNG.sol");

var RealMath = artifacts.require("./RealMath.sol");

module.exports = function(deployer) {
  deployer.deploy(RealMath);
  deployer.link(RealMath, RNG);
  deployer.deploy(RNG);
};
