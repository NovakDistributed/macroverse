let MacroverseSystemGenerator = artifacts.require("MacroverseSystemGenerator");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseSystemGenerator', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    
    await instance.getObjectPlanetCount.call('bob', mv.objectClass['MainSequence'], mv.spectralType['TypeG']).then(function () {
      assert.ok(false, "Successfully made unauthorized query")
    }).catch(async function () {
      assert.ok(true, "Unauthorized query was rejected")
    })
  })
  
  it("should let us change access control to unrestricted", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let unrestricted = await UnrestrictedAccessControl.deployed()
    await instance.changeAccessControl(unrestricted.address)
    
    assert.ok(true, "Access control can be changed without error")
    
  })
})
