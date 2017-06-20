let MacroversePrototype = artifacts.require("MacroversePrototype");
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
  
  it("should let us read the density", async function() {
    let instance = await MacroversePrototype.deployed()
    var density = fromReal(await instance.getGalaxyDensity.call(0, 0, 0))
    
    assert.isAbove(density, 0.899999, "density at the center of the galaxy is not too small")
    assert.isBelow(density, 0.900001, "density at the center of the galaxy is not too big")
  })
  
  it("should produce stars of reasonable mass", async function() {
    let instance = await MacroversePrototype.deployed()
    let seed = await instance.getSectorObjectSeed.call(0, 0, 0, 0)
    let objClass = (await instance.getObjectClass.call(seed)).toNumber()
    let objType = (await instance.getObjectSpectralType.call(seed, objClass)).toNumber()
    let objMass = fromReal(await instance.getObjectMass.call(seed, objClass, objType))
    
    assert.isBelow(objMass, 100, "A star is <100 solar masses")
    
  })
  
  it("should let us scan sector 0", async function() {
    let instance = await MacroversePrototype.deployed()
    
    let starCount = (await instance.getSectorObjectCount.call(0, 0, 0)).toNumber()
    console.log("Stars in origin sector: ", starCount)
    
    let starPromises = []
    
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
      }())
    }
    
    await Promise.all(starPromises)
    
    assert.ok(true, "Report can be printed without error")
    
  })
  
  
  
})