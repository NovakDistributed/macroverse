let MacroverseSystemGenerator = artifacts.require("MacroverseSystemGenerator");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseSystemGenerator', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    
    let failure_found = false
    
    await (instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'], {from: accounts[1]}).catch(async function () {
      failure_found = true
    }))
    
    assert.equal(failure_found, true, "Unauthorized query should fail")
  })
  
  it("should let us change access control to unrestricted", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let unrestricted = await UnrestrictedAccessControl.deployed()
    await instance.changeAccessControl(unrestricted.address)
    
    assert.ok(true, "Access control can be changed without error")
    
  })
  
  it("should then accept queries", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    
    let failure_found = false
    
    await (instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'], {from: accounts[1]}).catch(async function () {
      failure_found = true
    }))
    
    assert.equal(failure_found, false, "Authorized query should succeed")
  })
  
  it("should have 8 planets in the fred system", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let count = (await instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'])).toNumber()
    assert.equal(count, 8);
  
  })
  
  it("should have a Terrestrial planet first", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetClass = mv.planetClasses[(await instance.getPlanetClass.call('fred', 0, 8)).toNumber()]
    assert.equal(planetClass, 'Terrestrial')
  })
  
  it("should be a super-earth", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetClassNum = mv.planetClass['Terrestrial']
    let planetMass = mv.fromReal(await instance.getPlanetMass.call('fred', 0, planetClassNum))
    
    assert.isAbove(planetMass, 6.27)
    assert.isBelow(planetMass, 6.29)
  })
  
  it("should have an orbit from about 0.32 to 0.35 AU", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetClassNum = mv.planetClass['Terrestrial']
    
    let realPeriapsis = await instance.getPlanetPeriapsis.call('fred', 0, planetClassNum, mv.toReal(0))
    let realApoapsis =  await instance.getPlanetApoapsis.call('fred', 0, planetClassNum, realPeriapsis)
    let realClearance =  await instance.getPlanetClearance.call('fred', 0, planetClassNum, realApoapsis)
    
    assert.isAbove(mv.fromReal(realPeriapsis) / mv.AU, 0.32)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.33)
    
    assert.isAbove(mv.fromReal(realApoapsis) / mv.AU, 0.35)
    assert.isBelow(mv.fromReal(realApoapsis) / mv.AU, 0.36)

    // We sould also have reasonably symmetric-ish clearance    
    assert.isAbove(mv.fromReal(realClearance) / mv.AU, 0.60)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.70)
  })
  
  it("should let us dump the whole system", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let count = (await instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'])).toNumber()
    
    var lastClearance = mv.toReal(0)
    
    for (let i = 0; i < count; i++) {
        let planetClassNum = (await instance.getPlanetClass.call('fred', i, count)).toNumber()
        let realMass = await instance.getPlanetMass.call('fred', i, planetClassNum)
        let planetMass = mv.fromReal(realMass)
        let realPeriapsis = await instance.getPlanetPeriapsis.call('fred', i, planetClassNum, lastClearance)
        let planetPeriapsis = mv.fromReal(realPeriapsis) / mv.AU;
        let realApoapsis = await instance.getPlanetApoapsis.call('fred', i, planetClassNum, realPeriapsis)
        let planetApoapsis = mv.fromReal(realApoapsis) / mv.AU;
        lastClearance = await instance.getPlanetClearance.call('fred', i, planetClassNum, realApoapsis)
        console.log('Planet ' + i + ': ' + mv.planetClasses[planetClassNum] + ' with mass ' +
            planetMass + ' Earths between ' + planetPeriapsis + ' and ' + planetApoapsis + ' AU')
    }
        
  
  })
  
})
