let MacroverseTerrainGenerator = artifacts.require("MacroverseTerrainGenerator");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseTerrainGenerator', function(accounts) {
  
  it("should give trixel heights that reflect midpoint displacement with a scaling factor of 1/2", async function() {
    let instance = await MacroverseTerrainGenerator.deployed()
    
    // Prepare token IDs for smaller and smaller trixels
    let trixels = []
    let keypath = '0.1.2.0.0.-1'
    for (let i = 0; i < 27; i++) {
      keypath = keypath + '.1'
      trixels.push(mv.keypathToToken(keypath))
    }
    
    let heights = []
    for (let token of trixels) {
      let height = instance.getTrixelHeight.call(token, '0x12345').then(mv.fromReal)
      heights.push(height)
    }
    for (let i = 0; i < heights.length; i++) {
      heights[i] = await heights[i]
    }
    
    for (let i = 0; i < heights.length; i++) {
      console.log(heights[i])
      if (i > 0) {
        assert.isBelow(Math.abs(heights[i] - heights[i - 1]), Math.pow(2, -i), "Difference from previous height is not too large")
      }
    }
    
  })
  
})
