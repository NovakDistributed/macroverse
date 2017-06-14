var RNG = artifacts.require("./RNG.sol");

var RealMath = artifacts.require("./RealMath.sol");
var StringLib = artifacts.require("./deps/StringLib.sol");
var Strings = artifacts.require("./deps/strings.sol");

module.exports = function(deployer) {
  deployer.deploy(RealMath);
  deployer.deploy(StringLib);
  deployer.deploy(Strings);
  deployer.link(RealMath, RNG);
  deployer.link(StringLib, RNG);
  deployer.deploy(RNG);
};
