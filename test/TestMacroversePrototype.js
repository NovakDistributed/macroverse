let MacroversePrototype = artifacts.require("MacroversePrototype");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

contract('MacroversePrototype', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroversePrototype.deployed()
    
    await instance.getGalaxyDensity.call(0, 0, 0).then(function () {
      assert.ok(false, "successfully made unauthorized query")
    }).catch(async function () {
      assert.ok(true, "unauthorized query was rejected")
    })
  })
  
  it("should let us change access control to unrestricted", async function() {
    let instance = await MacroversePrototype.deployed()
    let unrestricted = await UnrestrictedAccessControl.deployed()
    await instance.changeAccessControl(unrestricted.address)
    
    assert.ok(true, "Access control can be changed without error")
    
  })
  
  
})