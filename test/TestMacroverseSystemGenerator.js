let MacroverseSystemGenerator = artifacts.require('MacroverseSystemGenerator')
let UnrestrictedAccessControl = artifacts.require('UnrestrictedAccessControl')

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

  it("should have a luminosity that is reasonable", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let luminosity = mv.fromReal(await instance.getObjectLuminosity.call('fred', mv.objectClass['MainSequence'], mv.toReal(1.0)))
    // Luminosities are randomized to between 95% and 105% of expected
    assert.isAbove(luminosity, 0.95)
    assert.isBelow(luminosity, 1.05)
  })

  it("should have a habitable zone that is reasonable", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let [realHabStart, realHabEnd] = await instance.getObjectHabitableZone.call(mv.toReal(1.0))

    let habStart = mv.fromReal(realHabStart)
    let habEnd = mv.fromReal(realHabEnd)

    // This should scale with the square root of the luminosity (so we scale the bounds)
    assert.isAbove(habStart / mv.AU, 0.75 * Math.sqrt(0.95))
    assert.isBelow(habStart / mv.AU, 0.75 * Math.sqrt(1.05))
    assert.isAbove(habEnd / mv.AU, 2.0 * Math.sqrt(0.95))
    assert.isBelow(habEnd / mv.AU, 2.0 * Math.sqrt(1.05))
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
  
  it("should have an orbit from about 0.24 to 0.29 AU", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClassNum = mv.planetClass['Terrestrial']
    let parentClassNum = mv.objectClass['MainSequence']
    let parentTypeNum = mv.spectralType['TypeG']
    let parentRealMass = mv.toReal(1.0)
    let parentRealLuminosity = await instance.getObjectLuminosity.call('fred', parentClassNum, parentRealMass)

    let [realHabStart, realHabEnd] = await instance.getObjectHabitableZone.call(parentRealLuminosity)

    let [realPeriapsis, realApoapsis, realClearance] = await instance.getPlanetOrbitDimensions.call(realHabStart, realHabEnd,
      planetSeed, planetClassNum, mv.toReal(0))
    
    assert.isAbove(mv.fromReal(realPeriapsis) / mv.AU, 0.24)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.25)
    
    assert.isAbove(mv.fromReal(realApoapsis) / mv.AU, 0.29)
    assert.isBelow(mv.fromReal(realApoapsis) / mv.AU, 0.30)

    // We sould also have reasonably symmetric-ish clearance    
    assert.isAbove(mv.fromReal(realClearance) / mv.AU, 0.60)
    assert.isBelow(mv.fromReal(realPeriapsis) / mv.AU, 0.70)
  })
  
  it("should have a semimajor axis of 0.27 AU and an eccentricity of about 0.08", async function() {
  
    let instance = await MacroverseSystemGenerator.deployed()
    let planetSeed = await instance.getPlanetSeed.call('fred', 0)
    let planetClassNum = mv.planetClass['Terrestrial']
    let parentClassNum = mv.objectClass['MainSequence']
    let parentTypeNum = mv.spectralType['TypeG']
    let parentRealMass = mv.toReal(1.0)
    let parentRealLuminosity = await instance.getObjectLuminosity.call('fred', parentClassNum, parentRealMass)

    let [realHabStart, realHabEnd] = await instance.getObjectHabitableZone.call(parentRealLuminosity)

    let [realPeriapsis, realApoapsis, realClearance] = await instance.getPlanetOrbitDimensions.call(realHabStart, realHabEnd,
      planetSeed, planetClassNum, mv.toReal(0))
    
    let [realSemimajor, realEccentricity] = await instance.convertOrbitShape.call(realPeriapsis, realApoapsis)
    
    assert.isAbove(mv.fromReal(realSemimajor) / mv.AU, 0.27)
    assert.isBelow(mv.fromReal(realSemimajor) / mv.AU, 0.28)
    
    assert.isAbove(mv.fromReal(realEccentricity), 0.08)
    assert.isBelow(mv.fromReal(realEccentricity), 0.09)
  
  })
  
  it("should let us dump the whole system", async function() {
    let instance = await MacroverseSystemGenerator.deployed()
    let parentClassNum = mv.objectClass['MainSequence']
    let parentTypeNum = mv.spectralType['TypeG']

    let parentRealMass = mv.toReal(1.0)
    let parentRealLuminosity = await instance.getObjectLuminosity.call('fred', parentClassNum, parentRealMass)

    let [realHabStart, realHabEnd] = await instance.getObjectHabitableZone.call(parentRealLuminosity)

    let count = (await instance.getObjectPlanetCount.call('fred', parentClassNum, parentTypeNum)).toNumber()
    
    var prevClearance = mv.toReal(0)
    
    for (let i = 0; i < count; i++) {
      // Define the planet
      let planetSeed = await instance.getPlanetSeed.call('fred', i)
      let planetClassNum = (await instance.getPlanetClass.call(planetSeed, i, count)).toNumber()
      let realMass = await instance.getPlanetMass.call(planetSeed, planetClassNum)
      let planetMass = mv.fromReal(realMass)
      
      // Define the orbit shape
      let [realPeriapsis, realApoapsis, newClearance] = await instance.getPlanetOrbitDimensions.call(realHabStart, realHabEnd,
        planetSeed, planetClassNum, prevClearance)
      prevClearance = newClearance

      let planetPeriapsis = mv.fromReal(realPeriapsis) / mv.AU;
      let planetApoapsis = mv.fromReal(realApoapsis) / mv.AU;
      
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
  
})
