// This contract is at risk of being too big.
// See https://ethereum.stackexchange.com/a/48568 for sizing code
var MacroverseUniversalRegistry = artifacts.require('MacroverseUniversalRegistry')

contract('MacroverseUniversalRegistry', function(accounts) {
  it("get the size of the contract", function() {
    return MacroverseUniversalRegistry.deployed().then(function(instance) {
      var bytecode = instance.constructor._json.bytecode
      var deployed = instance.constructor._json.deployedBytecode
      var sizeOfB  = bytecode.length / 2
      var sizeOfD  = deployed.length / 2
      console.log("size of bytecode in bytes = ", sizeOfB)
      console.log("size of deployed in bytes = ", sizeOfD)
      console.log("initialisation and constructor code in bytes = ", sizeOfB - sizeOfD)
    })  
  })
})
