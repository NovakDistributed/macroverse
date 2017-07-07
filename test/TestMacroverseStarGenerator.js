let MacroverseStarGenerator = artifacts.require("MacroverseStarGenerator");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

// Define a bit of JS for interpreting contract results.

let REAL_FBITS = 40;
let REAL_ONE = web3.toBigNumber(2).toPower(REAL_FBITS);

function fromReal(real) {
  // Convert from 40 bit fixed point
  return real.dividedBy(REAL_ONE).toNumber()
}

let objectClasses = ['Supergiant', 'Giant', 'MainSequence', 'WhiteDwarf', 'NeutronStar', 'BlackHole']
let spectralTypes = ['TypeO', 'TypeB', 'TypeA', 'TypeF', 'TypeG', 'TypeK', 'TypeM', 'NotApplicable']

contract('MacroverseStarGenerator', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    
    await instance.getGalaxyDensity.call(0, 0, 0).then(function () {
      assert.ok(false, "Successfully made unauthorized query")
    }).catch(async function () {
      assert.ok(true, "Unauthorized query was rejected")
    })
  })
  
  it("should let us change access control to unrestricted", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let unrestricted = await UnrestrictedAccessControl.deployed()
    await instance.changeAccessControl(unrestricted.address)
    
    assert.ok(true, "Access control can be changed without error")
    
  })
  
  it("should let us read the density", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let density = fromReal(await instance.getGalaxyDensity.call(0, 0, 0))
    
    assert.isAbove(density, 0.899999, "Density at the center of the galaxy is not too small")
    assert.isBelow(density, 0.900001, "Density at the center of the galaxy is not too big")
  })
  
  it("should report 0.9 density out to a radius of 500", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let density = fromReal(await instance.getGalaxyDensity.call(999, 0, 0))
    assert.isAbove(density, 0.899999, "Density just inside the central bubble is not too small")
    assert.isBelow(density, 0.900001, "Density just inside the central bubble is not too big")
    
    density = fromReal(await instance.getGalaxyDensity.call(250, 866, 433))
    assert.isAbove(density, 0.899999, "Density just inside the central bubble is not too small")
    assert.isBelow(density, 0.900001, "Density just inside the central bubble is not too big")
    
    density = fromReal(await instance.getGalaxyDensity.call(250, 866, 433))
    assert.isAbove(density, 0.899999, "Density just inside the central bubble is not too small")
    assert.isBelow(density, 0.900001, "Density just inside the central bubble is not too big")
    
    density = fromReal(await instance.getGalaxyDensity.call(35, 872, 488))
    assert.isAbove(density, 0.899999, "Density just inside the central bubble is not too small")
    assert.isBelow(density, 0.900001, "Density just inside the central bubble is not too big")
    
    density = fromReal(await instance.getGalaxyDensity.call(131, 0, 0))
    assert.isAbove(density, 0.899999, "Density well inside the central bubble is not too small")
    assert.isBelow(density, 0.900001, "Density well inside the central bubble is not too big")
    
    density = fromReal(await instance.getGalaxyDensity.call(35, 872, 489))
    assert.isBelow(density, 0.899999, "Density just outside the central bubble is smaller")
    
    density = fromReal(await instance.getGalaxyDensity.call(0, 1000, 0))
    assert.isBelow(density, 0.499999, "Density just above  the central bubble is smaller still")
  })
  
  it("should report 1/60 density way out", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let density = fromReal(await instance.getGalaxyDensity.call(999, 999, 999))
    assert.isAbove(density, 0.016, "Density way out is not too small")
    assert.isBelow(density, 0.017, "Density way out is not too big")
  })
  
  it("should report 1/2 density in the main disk", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let density = fromReal(await instance.getGalaxyDensity.call(-6000, -5, -13))
    assert.isAbove(density, 0.499999, "Density in disk is not too small")
    assert.isBelow(density, 0.500001, "Density in disk is not too big")
  })
  
  it("should have lots of things in the disk", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let objectCount = 0;
    let sectorCount = 0;
    for (let x = -1; x < 2; x++) {
      for(let y = -1; y < 2; y++) {
        for (let z = -1; z < 2; z++) {
          let sectorObjects = (await instance.getSectorObjectCount.call(x, y, z)).toNumber()
          console.log(x, y, z, sectorObjects)
          objectCount += sectorObjects
          sectorCount += 1
        }
      }
    }
    
    let average = objectCount / sectorCount;
    
    assert.isAbove(average, 20, "Enough objects exist in the core")
    assert.isBelow(average, 30, "Too many objects don't exist in the core")
  })
  
  it("should have some objects way out", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let objectCount = 0;
    let sectorCount = 0;
    for (let x = -1; x < 2; x++) {
      for(let y = -1; y < 2; y++) {
        for (let z = -1; z < 2; z++) {
          let sectorObjects = (await instance.getSectorObjectCount.call(x + 999, y + 999, z + 999)).toNumber()
          console.log(x, y, z, sectorObjects)
          objectCount += sectorObjects
          sectorCount += 1
        }
      }
    }
    
    let average = objectCount / sectorCount;
    
    assert.isAbove(average, 0, "Enough objects exist in deep space")
    assert.isBelow(average, 1, "Too many objects don't exist in deep space")
  })
  
  it("should have a moderate number of objects in the disk", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let objectCount = 0;
    let sectorCount = 0;
    for (let x = -1; x < 2; x++) {
      for(let y = -1; y < 2; y++) {
        for (let z = -1; z < 2; z++) {
          let sectorObjects = (await instance.getSectorObjectCount.call(x - 3000, y, z + 3000)).toNumber()
          console.log(x, y, z, sectorObjects)
          objectCount += sectorObjects
          sectorCount += 1
        }
      }
    }
    
    let average = objectCount / sectorCount;
    
    assert.isAbove(average, 10, "Enough objects exist in the disk")
    assert.isBelow(average, 20, "Too many objects don't exist in the disk")
  })
  
  it("should produce stars of reasonable mass", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    let seed = await instance.getSectorObjectSeed.call(0, 0, 0, 0)
    let objClass = (await instance.getObjectClass.call(seed)).toNumber()
    let objType = (await instance.getObjectSpectralType.call(seed, objClass)).toNumber()
    let objMass = fromReal(await instance.getObjectMass.call(seed, objClass, objType))
    
    assert.isBelow(objMass, 100, "A star is <100 solar masses")
    
  })
  
  it("should let us scan sector 0", async function() {
    let instance = await MacroverseStarGenerator.deployed()
    
    let starCount = (await instance.getSectorObjectCount.call(0, 0, 0)).toNumber()
    console.log("Stars in origin sector: ", starCount)
    
    let starPromises = []
    
    let foundPlanets = false;
    
    for (let star = 0; star < starCount; star++) {
      
      starPromises.push(async function() {
      
        // Generate each star
        // Make a seed
        let seed = await instance.getSectorObjectSeed.call(0, 0, 0, star)
        
        // Decide on a position
        let [ x, y, z] = await instance.getObjectPosition.call(seed)
        x = fromReal(x)
        y = fromReal(y)
        z = fromReal(z)
        
        // Then get the class
        let objClass = (await instance.getObjectClass.call(seed)).toNumber()
        // Then make the spectral type
        let objType = (await instance.getObjectSpectralType.call(seed, objClass)).toNumber()
        // Then make the mass
        let objMass = fromReal(await instance.getObjectMass.call(seed, objClass, objType))
        // And decide if it has planets
        let hasPlanets = await instance.getObjectHasPlanets.call(seed, objClass, objType)
        
        console.log("Star " + star + " at " + x + "," + y + "," + z + " ly is a " + objectClasses[objClass] + " " + spectralTypes[objType] + " of " + objMass + " solar masses" + (hasPlanets ? " with planets" : ""))
        
        if (hasPlanets) {
          foundPlanets = true;
        }
        
      }())
    }
    
    await Promise.all(starPromises)
    
    assert.ok(true, "Report can be printed without error")
    assert.equal(foundPlanets, true, "Planets are found")
    
  })
  
  
  
})