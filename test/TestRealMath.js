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
})
