let MacroverseSystemGenerator = artifacts.require('MacroverseSystemGenerator')
let MacroverseMoonGenerator = artifacts.require('MacroverseMoonGenerator')
let UnrestrictedAccessControl = artifacts.require('UnrestrictedAccessControl')

// Load the Macroverse module JavaScript
let mv = require('../src')

// Define the parameters of our test planet
const TEST_SEED = '0x6e617461736861'
const TEST_CLASS = mv.worldClass['Terrestrial']

contract('MacroverseMoonGenerator', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroverseMoonGenerator.deployed()
    
    let failure_found = false
    
    await (instance.getPlanetMoonCount.call(TEST_SEED, TEST_CLASS, {from: accounts[1]}).catch(async function () {
      failure_found = true
    }))
    
    assert.equal(failure_found, true, "Unauthorized query should fail")
  })
  
  it("should let us change access control to unrestricted", async function() {
    let instance = await MacroverseMoonGenerator.deployed()
    let unrestricted = await UnrestrictedAccessControl.deployed()
    await instance.changeAccessControl(unrestricted.address)
    
    assert.ok(true, "Access control can be changed without error")
    
  })
  
  it("should then accept queries", async function() {
    let instance = await MacroverseMoonGenerator.deployed()
    
    let failure_found = false
    
    await (instance.getPlanetMoonCount.call(TEST_SEED, TEST_CLASS, {from: accounts[1]}).catch(async function () {
      failure_found = true
    }))
    
    assert.equal(failure_found, false, "Authorized query should succeed")
  })
  
  it("should have a moon around our test planet", async function() {
    let instance = await MacroverseMoonGenerator.deployed()
    let count = (await instance.getPlanetMoonCount.call(TEST_SEED, TEST_CLASS)).toNumber()
    assert.equal(count, 1);
  
  })

  it("should let us dump all the moons", async function() {
    let instance = await MacroverseMoonGenerator.deployed()

    // We also need the system generator for some moon properties
    let sysgen = await MacroverseSystemGenerator.deployed()

    // Parent mass is in Earth masses
    let parentRealMass = mv.toReal(1.0)

    let count = (await instance.getPlanetMoonCount.call(TEST_SEED, TEST_CLASS)).toNumber()
    
    // Get the moon scale which defines the basic size of the moon system.
    let realMoonScale = await instance.getPlanetMoonScale.call(TEST_SEED, parentRealMass)

    var prevClearance = mv.toReal(0)
    
    for (let i = 0; i < count; i++) {
      // Define the moon
      let moonSeed = await sysgen.getWorldSeed.call(TEST_SEED, i)
      let moonClassNum = (await instance.getMoonClass.call(TEST_CLASS, moonSeed, i)).toNumber()
      let realMass = await sysgen.getWorldMass.call(moonSeed, moonClassNum)
      let moonMass = mv.fromReal(realMass)
      
      // Define the orbit shape
      let orbitShape = await instance.getMoonOrbitDimensions.call(realMoonScale,
        moonSeed, moonClassNum, prevClearance)
      console.log(orbitShape)
      let [realPeriapsis, realApoapsis, newClearance] = [orbitShape[0], orbitShape[1], orbitShape[2]]
      prevClearance = newClearance
      
      // Compute useful versions of this in lunar distances
      let moonPeriapsis = mv.fromReal(realPeriapsis) / mv.LD;
      let moonApoapsis = mv.fromReal(realApoapsis) / mv.LD;

      let converted = await sysgen.convertOrbitShape.call(realPeriapsis, realApoapsis)
      let [realSemimajor, realEccentricity] = [converted[0], converted[1]]
      let moonEccentricity = mv.fromReal(realEccentricity);
      
      // Define the orbital plane. Make sure to convert everything to degrees for display.
      let realLan = await sysgen.getWorldLan.call(moonSeed)
      let moonLan = mv.degrees(mv.fromReal(realLan))
      // TODO: Inclination and LAN ought to group for moons, for a common orbital plane out of the elliptic
      let realInclination = await instance.getMoonInclination.call(moonSeed, moonClassNum)
      let moonInclination = mv.degrees(mv.fromReal(realInclination))
      
      // Define the position in the orbital plane
      let realAop = await sysgen.getWorldAop.call(moonSeed)
      let moonAop = mv.degrees(mv.fromReal(realAop))
      let realMeanAnomalyAtEpoch = await sysgen.getWorldMeanAnomalyAtEpoch.call(moonSeed)
      let moonMeanAnomalyAtEpoch = mv.degrees(mv.fromReal(realMeanAnomalyAtEpoch))
      
      console.log('Moon ' + i + ': ' + mv.worldClasses[moonClassNum] + ' with mass ' +
        moonMass + ' Earths between ' + moonPeriapsis + ' and ' + moonApoapsis + ' LD')
      console.log('\tEccentricity: ' + moonEccentricity + ' LAN: ' + moonLan + '° Inclination: ' + moonInclination + '°')
      console.log('\tAOP: ' + moonAop + '° Mean Anomaly at Epoch: ' + moonMeanAnomalyAtEpoch + '°')
    }
        
  
  })
  
})
