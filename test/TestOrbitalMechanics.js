let OrbitalMechanics = artifacts.require('OrbitalMechanics')

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('OrbitalMechanics', function(accounts) {
  
  it("should compute correct mean angular motions", async function() {
    let instance = await OrbitalMechanics.deployed()

    // Earth semimajor axis is 1.00000011 AU from https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
    let real_semimajor_meters =  mv.toReal(1.00000011 * mv.AU)
    // The sun is exactly 1 solar mass. Ignore the fact that this means the unit gets smaller over time...
    let real_sols = mv.toReal(1)
    let meanAngularMotion = mv.fromReal(await instance.computeMeanAngularMotion.call(real_sols, real_semimajor_meters))

    assert.approximately(meanAngularMotion, 2 * Math.PI / mv.SIDERIAL_YEAR * mv.JULIAN_YEAR, 1E-10,
      "mean angular motion of Earth should be 2 pi radians per Siderial year")
  })

})
