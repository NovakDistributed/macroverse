let MacroversePrototype = artifacts.require("MacroversePrototype");
let UnrestrictedAccessControl = artifacts.require("UnrestrictedAccessControl");

contract('MacroversePrototype', function(accounts) {
  it("should initially reject queries", async function() {
    let instance = await MacroversePrototype.deployed()
    
    await instance.getStarType.call().then(function () {
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
  
  it("should generate a G2 class star", async function() {
    // Find the contract
    let instance = await MacroversePrototype.deployed()
    // Grab its star info
    let starType = await instance.getStarType.call()
    // Turn all the entries into numbers
    let translated = starType.map((x) => {
      return x.toNumber()
    })
    
    // 2 = MainSequence
    // 4 = TypeG
    // 2 = subtype 2
    assert.equal(translated[0], 2, "Seed generates a MainSequence star")
    assert.equal(translated[1], 4, "Seed generates a TypeG star")
    assert.equal(translated[2], 2, "Seed generates a subtype 2 star")
   
  })
  
  it("should generate a system with 10 planets", async function() {
    
    let instance = await MacroversePrototype.deployed()
    
    // Pass in system facts to avoid needing to re-generate them.
    let planetCount = await instance.getPlanetCount.call(2, 4)
    
    assert.equal(planetCount.toNumber(), 10, "Seed generates a star with 10 planets")
    
  })
  
  it("should generate a system with planets laid out appropriately", async function() {
    let instance = await MacroversePrototype.deployed()
    
    // Get planet count
    let planetCount = (await instance.getPlanetCount.call(2, 4)).toNumber()
    
    // Get planets in hot, habitable, and cold zones
    let inA = (await instance.getPlanetsInZone.call(planetCount, 0)).toNumber()
    let inB = (await instance.getPlanetsInZone.call(planetCount, 1)).toNumber()
    let inC = (await instance.getPlanetsInZone.call(planetCount, 2)).toNumber()
    
    assert.equal(inA, 2, "2 planets in hot zone")
    assert.equal(inB, 2, "2 planets in habitable zone")
    assert.equal(inC, 6, "6 planets in cold zone")
    
  })
  
  it("should generate the appropriate planet types", async function() {
    let instance = await MacroversePrototype.deployed()
    
    // Set star parameters
    let starClass = 2; // MainSequence
    let starType = 4; // TypeG
    
    // First 2 planets are in the hot zone
    let planet0 = (await instance.getPlanetType.call(0, 0, starClass, starType)).toNumber()
    let planet1 = (await instance.getPlanetType.call(1, 0, starClass, starType)).toNumber()
    // Next 2 are in the habitable zone
    let planet2 = (await instance.getPlanetType.call(2, 1, starClass, starType)).toNumber()
    let planet3 = (await instance.getPlanetType.call(3, 1, starClass, starType)).toNumber()
    // Last 6 are in the cold zone
    let planet4 = (await instance.getPlanetType.call(4, 2, starClass, starType)).toNumber()
    let planet5 = (await instance.getPlanetType.call(5, 2, starClass, starType)).toNumber()
    let planet6 = (await instance.getPlanetType.call(6, 2, starClass, starType)).toNumber()
    let planet7 = (await instance.getPlanetType.call(7, 2, starClass, starType)).toNumber()
    let planet8 = (await instance.getPlanetType.call(8, 2, starClass, starType)).toNumber()
    let planet9 = (await instance.getPlanetType.call(9, 2, starClass, starType)).toNumber()
    
    //console.log(planet0, planet1, planet2, planet3, planet4, planet5, planet6, planet7, planet8, planet9)
    
    assert.equal(planet0, 2, "planet 0 is VaccuumRock")
    assert.equal(planet1, 2, "planet 1 is VaccuumRock")
    assert.equal(planet2, 4, "planet 2 is Desert")
    assert.equal(planet3, 4, "planet 3 is Desert")
    assert.equal(planet4, 5, "planet 4 is Hostile")
    assert.equal(planet5, 1, "planet 5 is Giant")
    assert.equal(planet6, 1, "planet 6 is Giant")
    assert.equal(planet7, 3, "planet 7 is VaccuumIce")
    assert.equal(planet8, 1, "planet 8 is Giant")
    assert.equal(planet9, 1, "planet 9 is Giant")
  
  })
  
  it("should flesh out important planets", async function() {
    let instance = await MacroversePrototype.deployed()
     
    // Planet 4 is hostile (type 5)
    let planet4diam = (await instance.getPlanetDiameter.call(4, 5)).toNumber()
    let planet4moons = (await instance.getPlanetMoonCount.call(4, 5)).toNumber()
    
    // Planet 5 is a giant (type 1)
    let planet5diam = (await instance.getPlanetDiameter.call(5, 1)).toNumber()
    let planet5moons = (await instance.getPlanetMoonCount.call(5, 1)).toNumber()
    
    assert.equal(planet4diam, 14000, "planet 4 has a diameter of 14000 km")
    assert.equal(planet4moons, 1, "planet 4 has 1 moon")
    
    assert.equal(planet5diam, 90000, "planet 5 has a diameter of 90000 km")
    assert.equal(planet5moons, 15, "planet 5 has 15 moons")
    
  })
  
})