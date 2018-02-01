let OrbitalMechanics = artifacts.require('OrbitalMechanics')

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('OrbitalMechanics', function(accounts) {
  
  it("should compute correct mean angular motions", async function() {
    let instance = await OrbitalMechanics.deployed()

    let meanAngularMotion = mv.fromReal(await instance.computeMeanAngularMotion.call(mv.toReal(1), mv.toReal(149598023 * 1000)))

    // TODO: this needs to be *way* more accurate!
    assert.approximately(meanAngularMotion, 2 * Math.PI, 0.02,
      "mean angular motion of Earth should be 2 pi radians per year")
  })

})
