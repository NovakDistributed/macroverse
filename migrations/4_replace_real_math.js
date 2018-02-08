var RealMath = artifacts.require("./RealMath.sol");

module.exports = async function(deployer, network, accounts) {
  // Redeploy RealMath for Kepler Phase since it has been upgraded
  let oldAddress = RealMath.address
  await deployer.deploy(RealMath)
  if (RealMath.address == oldAddress) {
    throw new Error("Failed to replace RealMath!")
  }
};
