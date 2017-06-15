let MacroversePrototype = artifacts.require("MacroversePrototype");

contract('MacroversePrototype', function(accounts) {
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
  
})