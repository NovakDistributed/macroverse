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

  it("should compute correct radius", async function() {
    let instance = await OrbitalMechanics.deployed()

    for (let eccentricity of [0, 0.0001, 0.1, 0.5, 0.8, 0.9, 0.967, 0.99999]) {
      let real_eccentricity = mv.toReal(eccentricity)

      for (let ta of [0, 1, Math.PI/2, 4/3 * Math.PI, 2 * Math.PI - 0.0001]) {
        let real_ta = mv.toReal(ta)

        for (let semimajor_meters of [0.001, 1, 10, 1.00000011 * mv.AU, 10 * mv.AU, 100 * mv.AU]) {
          let real_semimajor_meters = mv.toReal(semimajor_meters)

          let correct_radius = semimajor_meters * (1 - Math.pow(eccentricity, 2)) / (1 + eccentricity * Math.cos(ta))
          
          let real_computed_radius = await instance.computeRadius.call(real_ta, real_semimajor_meters, real_eccentricity)
          let computed_radius = mv.fromReal(real_computed_radius)

          assert.approximately(computed_radius, correct_radius, real_semimajor_meters/1E10,
            "Radius of " + correct_radius + " should be computed from TA of " + ta + " at semimajor " + semimajor_meters + " and eccentricity " + eccentricity)


        }

      }
    }
  })

  it("should compute a current orbital position", async function() {
    let instance = await OrbitalMechanics.deployed()

    /**
     * I got this from the system generator test
     *
     * Terrestrial with mass 5.250290167260573 Earths between 1.0983088145299555 and 1.1140059916272032 AU
     *   Eccentricity: 0.007095363215739781 LAN: 107.55660144903162° Inclination: 0.17810602784688181°
     *   AOP: 265.32128537763356° Mean Anomaly at Epoch: 70.03141466547464°
     */
    
    // Define orbital parameters
    let semimajor_meters = (1.0983088145299555 + 1.1140059916272032) / 2 * mv.AU
    let eccentricity = 0.007095363215739781
    let lan = mv.radians(107.55660144903162)
    let inclination = mv.radians(0.17810602784688181)
    let aop = mv.radians(265.32128537763356)
    let ma0 = mv.radians(70.03141466547464)

    // Pretend it's around the sun
    let central_mass = 1.0

    // Decide what time it is
    let block = await web3.eth.getBlock(web3.eth.blockNumber)
    let mv_time = mv.yearsSinceEpoch(block.timestamp)
    console.log("The time is " + mv_time + " years since Macroverse epoch")

    // Convert to real
    let real_semimajor_meters = mv.toReal(semimajor_meters)
    let real_eccentricity = mv.toReal(eccentricity)
    let real_lan = mv.toReal(lan)
    let real_inclination = mv.toReal(inclination)
    let real_aop = mv.toReal(aop)
    let real_ma0 = mv.toReal(ma0)
    let real_central_mass = mv.toReal(central_mass)
    let real_time = mv.toReal(mv_time)
    
    // Track gas
    let totalGas = 0

    // Do all the orbit steps
    let real_mean_angular_motion = await instance.computeMeanAngularMotion.call(real_central_mass, real_semimajor_meters)
    totalGas += await instance.computeMeanAngularMotion.estimateGas(real_central_mass, real_semimajor_meters)
    let real_mean_anomaly = await instance.computeMeanAnomaly.call(real_ma0, real_mean_angular_motion, real_time)
    totalGas += await instance.computeMeanAnomaly.estimateGas(real_ma0, real_mean_angular_motion, real_time)
    let real_eccentric_anomaly = await instance.computeEccentricAnomaly.call(real_mean_anomaly, real_eccentricity)
    totalGas += await instance.computeEccentricAnomaly.estimateGas(real_mean_anomaly, real_eccentricity)
    let real_true_anomaly = await instance.computeTrueAnomaly.call(real_eccentric_anomaly, real_eccentricity)
    totalGas += await instance.computeTrueAnomaly.estimateGas(real_eccentric_anomaly, real_eccentricity)
    let real_radius = await instance.computeRadius.call(real_true_anomaly, real_semimajor_meters, real_eccentricity)
    totalGas += await instance.computeRadius.estimateGas(real_true_anomaly, real_semimajor_meters, real_eccentricity)
    let offset = await instance.computeCartesianOffset.call(real_radius, real_true_anomaly, real_lan, real_inclination, real_aop)
    let [real_x, real_y, real_z] = [offset[0], offset[1], offset[2]]
    totalGas += await instance.computeCartesianOffset.estimateGas(real_radius, real_true_anomaly, real_lan, real_inclination, real_aop)

    console.log("Planet currently at <" + mv.fromReal(real_x) + "," + mv.fromReal(real_y) + "," + mv.fromReal(real_z) + "> computed for " + totalGas + " gas")

    assert.isBelow(totalGas, 6721975)

  })
})
