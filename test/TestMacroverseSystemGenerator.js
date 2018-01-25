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
    
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClass = mv.planetClasses[(await instance.getPlanetClass.call(planetSeed, 0, 8)).toNumber()]
    assert.equal(planetClass, 'Terrestrial')
  })
  
  it("should be a super-earth", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClassNum = mv.planetClass['Terrestrial']
    let planetMass = mv.fromReal(await instance.getPlanetMass.call(planetSeed, planetClassNum))
    
    assert.isAbove(planetMass, 6.27)
    assert.isBelow(planetMass, 6.29)
  })
  
  it("should have an orbit from about 0.32 to 0.35 AU", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClassNum = mv.planetClass['Terrestrial']
    
    let realPeriapsis = await instance.getPlanetPeriapsis.call(planetSeed, planetClassNum, mv.toReal(0))
    let realApoapsis = await instance.getPlanetApoapsis.call(planetSeed, planetClassNum, realPeriapsis)
    let realClearance = await instance.getPlanetClearance.call(planetSeed, planetClassNum, realApoapsis)
    
    assert.isAbove(mv.fromReal(realPeriapsis) / mv.AU, 0.32)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.33)
    
    assert.isAbove(mv.fromReal(realApoapsis) / mv.AU, 0.35)
    assert.isBelow(mv.fromReal(realApoapsis) / mv.AU, 0.36)

    // We sould also have reasonably symmetric-ish clearance    
    assert.isAbove(mv.fromReal(realClearance) / mv.AU, 0.60)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.70)
  })
  
  it("should have a semimajor axis of 0.33 AU and an eccentricity of 0.04", async function() {
  
    let instance = await MacroverseSystemGenerator.deployed()
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClassNum = mv.planetClass['Terrestrial']
    
    let realPeriapsis = await instance.getPlanetPeriapsis.call(planetSeed, planetClassNum, mv.toReal(0))
    let realApoapsis = await instance.getPlanetApoapsis.call(planetSeed, planetClassNum, realPeriapsis)
    
    let [realSemimajor, realEccentricity] = await instance.convertOrbitShape.call(realPeriapsis, realApoapsis)
    
    assert.isAbove(mv.fromReal(realSemimajor) / mv.AU, 0.32)
    assert.isBelow(mv.fromReal(realSemimajor) / mv.AU, 0.34)
    
    assert.isAbove(mv.fromReal(realEccentricity), 0.03)
    assert.isBelow(mv.fromReal(realEccentricity), 0.05)
  
  })
  
  it("should let us dump the whole system", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let count = (await instance.getObjectPlanetCount.call('fred', mv.objectClass['MainSequence'], mv.spectralType['TypeG'])).toNumber()
    
    var lastClearance = mv.toReal(0)
    
    // TODO: adopt per-planet seeds!
    
    for (let i = 0; i < count; i++) {
        // Define the planet
        let planetSeed = await instance.getPlanetSeed.call('fred', i)
        let planetClassNum = (await instance.getPlanetClass.call(planetSeed, i, count)).toNumber()
        let realMass = await instance.getPlanetMass.call(planetSeed, planetClassNum)
        let planetMass = mv.fromReal(realMass)
        
        // Define the orbit shape
        let realPeriapsis = await instance.getPlanetPeriapsis.call(planetSeed, planetClassNum, lastClearance)
        let planetPeriapsis = mv.fromReal(realPeriapsis) / mv.AU;
        let realApoapsis = await instance.getPlanetApoapsis.call(planetSeed, planetClassNum, realPeriapsis)
        let planetApoapsis = mv.fromReal(realApoapsis) / mv.AU;
        lastClearance = await instance.getPlanetClearance.call(planetSeed, planetClassNum, realApoapsis)
        
        let [realSemimajor, realEccentricity] = await instance.convertOrbitShape.call(realPeriapsis, realApoapsis)
        let planetEccentricity = mv.fromReal(realEccentricity);
        
        // Define the orbital plane. Make sure to convert everything to degrees for display.
        let realLan = await instance.getPlanetLan.call(planetSeed)
        let planetLan = mv.degrees(mv.fromReal(realLan))
        let realInclination = await instance.getPlanetInclination.call(planetSeed, planetClassNum)
        let planetInclination = mv.degrees(mv.fromReal(realInclination))
        
        // Define the position in the orbital plane
        let realAop = await instance.getPlanetAop.call(planetSeed)
        let planetAop = mv.degrees(mv.fromReal(realAop))
        let realMeanAnomalyAtEpoch = await instance.getPlanetMeanAnomalyAtEpoch.call(planetSeed)
        let planetMeanAnomalyAtEpoch = mv.degrees(mv.fromReal(realMeanAnomalyAtEpoch))
        
        console.log('Planet ' + i + ': ' + mv.planetClasses[planetClassNum] + ' with mass ' +
            planetMass + ' Earths between ' + planetPeriapsis + ' and ' + planetApoapsis + ' AU')
        console.log('\tEccentricity: ' + planetEccentricity + ' LAN: ' + planetLan + '° Inclination: ' + planetInclination + '°')
        console.log('\tAOP: ' + planetAop + '° Mean Anomaly at Epoch: ' + planetMeanAnomalyAtEpoch + '°')
    }
        
  
  })
  
  // Now we test the compute functions
  // TODO: factor them out!
  
  it("should compute correct mean angular motions", async function() {
    let instance = await MacroverseSystemGenerator.deployed()

    let meanAngularMotion = mv.fromReal(await instance.computeMeanAngularMotion.call(mv.toReal(1), mv.toReal(149598023 * 1000)))

    // TODO: this needs to be *way* more accurate!
    assert.approximately(meanAngularMotion, 2 * Math.PI, 0.02,
      "mean angular motion of Earth should be 2 pi radians per year")


  })

  
})
