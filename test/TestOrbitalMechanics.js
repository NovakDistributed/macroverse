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

  it("should compute correct mean anomalies", async function() {
    let instance = await OrbitalMechanics.deployed()
  
    // Set mean anomaly at epoch to 0
    let real_ma0 = mv.toReal(0);

    // Compute Earth's mean motion
    let real_motion = mv.toReal(2 * Math.PI / mv.SIDERIAL_YEAR * mv.JULIAN_YEAR)

    // Multiply by this to get Julian years in a given number of complete orbits
    let s2j = mv.SIDERIAL_YEAR / mv.JULIAN_YEAR

    

    assert.approximately(mv.fromReal(await instance.computeMeanAnomaly.call(real_ma0, real_motion, mv.toReal(0))), 0, 1E-10,
      "at time 0 we are at 0 rads relative to epoch")

    assert.approximately(mv.fromReal(await instance.computeMeanAnomaly.call(mv.toReal(5), real_motion, mv.toReal(0))), 5, 1E-10,
      "mean anomaly at epoch is added in")

    // TODO: 1 siderial year comes out just slightly short of wrapping to 0 radians.
    assert.approximately(Math.cos(mv.fromReal(await instance.computeMeanAnomaly.call(real_ma0, real_motion, mv.toReal(1 * s2j)))), 1, 1E-10,
      "after 1 siderail year we are back at the start or nearly there")

    assert.approximately(Math.cos(mv.fromReal(await instance.computeMeanAnomaly.call(real_ma0, real_motion, mv.toReal(100000 * s2j)))), 1, 1E-10,
      "after 100k siderail years we are back at the start or nearly there")

    assert.isAtMost(Math.cos(mv.fromReal(await instance.computeMeanAnomaly.call(real_ma0, real_motion, mv.toReal(100000 * s2j)))), 2 * Math.PI,
      "angles actually wrap around")

    assert.approximately(mv.fromReal(await instance.computeMeanAnomaly.call(real_ma0, real_motion, mv.toReal(0.5 * s2j))), Math.PI, 1E-10,
      "after half a year we are halfway around")

  })

})
