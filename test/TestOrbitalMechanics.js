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

  it("should compute correct eccentric anomalies", async function() {
    let instance = await OrbitalMechanics.deployed()

    for (let eccentricity of [0, 0.0001, 0.1, 0.5, 0.8, 0.9, 0.967, 0.99999]) {
      let real_eccentricity = mv.toReal(eccentricity)

      for (let correct_ea of [0, 1, Math.PI/2, 4/3 * Math.PI, 2 * Math.PI - 0.0001]) {
        // For each eccentric anomaly we want

        // Compute the corresponding mean anomaly
        let ma = correct_ea - eccentricity * Math.sin(correct_ea)
        let real_ma = mv.toReal(ma)

        // Back-compute the eccentric anomaly
        let real_computed_ea = await instance.computeEccentricAnomalyLimited.call(real_ma, real_eccentricity, 10)
        let computed_ea = mv.fromReal(real_computed_ea)

        // Make sure we got it right (within looser bounds for high and hard to generate eccentricities)
        assert.approximately(computed_ea, correct_ea, eccentricity < 0.9 ? 1E-8 : 1E-5,
          "EA of " + correct_ea + " should be computed from MA of " + ma + " at eccentricity " + eccentricity)

      }
    }

  })

  it("should compute correct true anomalies", async function() {
    let instance = await OrbitalMechanics.deployed()

    for (let eccentricity of [0, 0.0001, 0.1, 0.5, 0.8, 0.9, 0.967, 0.99999]) {
      let real_eccentricity = mv.toReal(eccentricity)

      for (let ea of [0, 1, Math.PI/2, 4/3 * Math.PI, 2 * Math.PI - 0.0001]) {
        // For each eccentric anomaly
        let real_ea = mv.toReal(ea)

        // Compute the target true anomaly
        let correct_ta = 2 * Math.atan2(Math.sqrt(1 - eccentricity) * Math.cos(ea / 2), Math.sqrt(1 + eccentricity) * Math.sin(ea / 2))

        // Compute the true anomaly in Solidity
        let real_computed_ta = await instance.computeTrueAnomaly.call(real_ea, real_eccentricity)
        let computed_ta = mv.fromReal(real_computed_ta)

        // Make sure we got it right
        // TODO: Make this more accurate by improving atan2 and sqrt
        assert.approximately(computed_ta, correct_ta, 1E-5,
          "TA of " + correct_ta + " should be computed from EA of " + ea + " at eccentricity " + eccentricity)

      }
    }
  })

})
