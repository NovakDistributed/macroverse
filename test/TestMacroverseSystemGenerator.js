let MacroverseSystemGenerator = artifacts.require("MacroverseSystemGenerator");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseSystemGenerator', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    
    await instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG']).then(function () {
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
  
  it("should have 8 planets in the fred system", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let count = (await instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'])).toNumber();
    assert.equal(count, 8);
  
  })
  
  it("should have a Terrestrial planet first", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetClass = mv.planetClasses[(await instance.getPlanetClass.call('fred', 0, 8)).toNumber()];
    assert.equal(planetClass, 'Terrestrial');
  })
  
  it("should be a super-earth", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetClassNum = mv.planetClass['Terrestrial']
    let planetMass = mv.fromReal(await instance.getPlanetMass.call('fred', 0, planetClassNum));
    
    assert.isAbove(planetMass, 6.27);
    assert.isBelow(planetMass, 6.29);
  })
  
})
