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
})