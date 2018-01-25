var RealMath = artifacts.require("RealMath")

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('RealMath', function(accounts) {
  it("should do multiplication", async function() {
    let instance = await RealMath.deployed()
    
    assert.equal(mv.fromReal(await instance.mul.call(mv.toReal(7), mv.toReal(8))), 56, "Multiplication of small integers works")
  })
  
  it("should do integer exponentiation", async function() {
    let instance = await RealMath.deployed()
    
    assert.equal(mv.fromReal(await instance.ipow.call(mv.toReal(10), 3)), Math.pow(10, 3), "Exponentiation to small powers works")
    
    assert.approximately(mv.fromReal(await instance.ipow.call(mv.toReal(1.001), 100)), 1.105, 0.001, "Exponentiation to large powers works")
    
  })
  
  it("should compute logarithms", async function() {
    let instance = await RealMath.deployed()
    
    for(let val of [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.5, 2.0, 3.0, 3.67, Math.PI, Math.E, 1000, 1E10, 4.28374782E25]) {
      let result = mv.fromReal(await instance.ln.call(mv.toReal(val)))

      // Make sure we get the right answer        
      assert.approximately(result, Math.log(val), 2E-11, "log of " + val + " should be approximately right")
      
      // Make sure we got it fast
      const MAX_ITERATIONS = 15
      let resultAtLimit = mv.fromReal(await instance.lnLimited.call(mv.toReal(val), MAX_ITERATIONS))
      assert.equal(result, resultAtLimit, "At most " + MAX_ITERATIONS + " iterations are sufficient for convergence")
    }
  })
    
  it("should compute exp", async function() {
    let instance = await RealMath.deployed()
    
    for(let val of [-10, -Math.PI, -1, -0.1, 0, 0.1, 0.2, 0.9, 1.0, 1.1, 1.5, 2.0, 3.0, 3.67, Math.PI, Math.E]) {
      let result = mv.fromReal(await instance.exp.call(mv.toReal(val)))

      // Make sure we get the right answer        
      assert.approximately(result, Math.exp(val), 1E-6, "exp of " + val + " should be approximately right")
    }
    
    // TODO: Test larger values (with less accuracy required?)
    // TODO: Make more accurate?
    
  })
  
  it("should compute pow", async function() {
    let instance = await RealMath.deployed()
    
    for (let base of [0, 1, -1, 0.5, 15.7, 1000, 36]) {
      for (let exponent of [0, 1, -1, 0.5, 1.9999, 2, 2.0001, 15.7]) {
        // For every base-exponent combination to test
        
        if (base == 0 && exponent < 0) {
          // Disallow division by 0
          continue
        }
        
        if (base < 0 && exponent != Math.trunc(exponent)) {
          // Negative numbers to fractional powers is not allowed
          continue
        }
        
        let truth = Math.pow(base, exponent)
        
        if (truth > Math.pow(2, 87)) {
          // Would be out of range
          continue
        }
        
        let result = mv.fromReal(await instance.pow.call(mv.toReal(base), mv.toReal(exponent)))

        // Make sure we get the right answer.
        // Make sure to give more slack for really big numbers.
        // TODO: Make this more accurate too somehow?       
        assert.approximately(result, truth,
          Math.max(Math.abs(truth / 10000), 1E-8),
          "pow of " + base + "^" + exponent + " should be approximately right")
      }
    }
  })
    
  it("should compute sqrt", async function() {
    let instance = await RealMath.deployed()
    
    for (let arg of [0, 0.5, 1, 1.61234, 25, 36, 458344 * 458344]) {
      let truth = Math.sqrt(arg)
      
      let result = mv.fromReal(await instance.sqrt.call(mv.toReal(arg)))

      // Make sure we get the right answer.
      // Make sure to give more slack for really big numbers.
      // TODO: Make this more accurate too somehow?       
      assert.approximately(result, truth,
        Math.max(Math.abs(truth / 10000), 1E-8),
        "square root of " + arg + " should be approximately right")
    }
  })
  
  it("should compute sin", async function() {
    let instance = await RealMath.deployed()
    
    for (let arg of [0.5, 0, -0.5, Math.PI, 2 * Math.PI, -2 * Math.PI, -1 * Math.PI, 1000, -999.3]) {
      let truth = Math.sin(arg)
      let result = mv.fromReal(await instance.sin.call(mv.toReal(arg)))

      // Make sure we get the right answer.
      assert.approximately(result, truth, 4E-11,
        "sin of " + arg + " should be approximately right")
    }
  })
  
  it("should compute cos", async function() {
    let instance = await RealMath.deployed()
    
    for (let arg of [0.5, 0, -0.5, Math.PI, 2 * Math.PI, -2 * Math.PI, -1 * Math.PI, 1000, -999.3]) {
      let truth = Math.cos(arg)
      let result = mv.fromReal(await instance.cos.call(mv.toReal(arg)))

      // Make sure we get the right answer.
      assert.approximately(result, truth, 4E-11,
        "cos of " + arg + " should be approximately right")
    }
  })
  
  it("should compute tan", async function() {
    let instance = await RealMath.deployed()
    
    for (let arg of [0.5, 0.0001, -0.5, Math.PI, 2 * Math.PI + 1E-5, -2 * Math.PI - 1E-6, -1 * Math.PI, 1000, -999.3]) {
      let truth = Math.tan(arg)
      let result = mv.fromReal(await instance.tan.call(mv.toReal(arg)))

      // Make sure we get the right answer.
      assert.approximately(result, truth, 2E-10,
        "tan of " + arg + " should be approximately right")
    }
  })
  
  it("should compute atan for small numbers", async function() {
    let instance = await RealMath.deployed()
    let truth = Math.atan(0.5)
    let result = mv.fromReal(await instance.atanSmall.call(mv.toReal(0.5)))
    assert.approximately(result, truth, 2E-6,
      "atan of 0.5 should be approximately right")
    // TODO: this needs to be WAY more accurate!
  })
  
  it("should compute atan2", async function() {
    let instance = await RealMath.deployed()
    
    for (let y of [0, 5, 0.01, 1, 10, -1, -10]) {
      for (let x of [0, 2, 0.01, 1, 10, -1, -10]) {
      
        if (x == 0 && y == 0) {
          // Not valid inputs
          continue;
        }
      
        let truth = Math.atan2(y, x)
        let result = mv.fromReal(await instance.atan2.call(mv.toReal(y), mv.toReal(x)))

        // Make sure we get the right answer.
        assert.approximately(result, truth, 2E-6,
          "atan2 of " + y + " and " + x + " should be approximately right")
      }
    }
  })
})
