let MacroverseExistenceChecker = artifacts.require("MacroverseExistenceChecker");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseExistenceChecker', function(accounts) {
  it("should say that star 0 in sector 0,0,0 exists", async function() {
    let instance = await MacroverseExistenceChecker.deployed()

    assert.equal(await instance.systemExists.call(0, 0, 0, 0), true, "We get the right result checking manually")
    assert.equal(await instance.exists.call(mv.keypathToToken('0.0.0.0')), true, "We get the right result checking by token")

  })

  it("should say that a series of locations used in other tests exist", async function() {
    let instance = await MacroverseExistenceChecker.deployed()

    for (let keypath of [
      '0.0.0.0',
      '0.0.0.0.0.-1.7.2.2.2',
      '0.0.0.0.0.-1.7.2.2.2.0',
      '0.0.0.0.0.-1.7.2.2.2.1',
      '0.0.0.0.0.-1.7.2.2.2.2',
      '0.0.0.0.0.-1.7.2.2.2.3'
    ]) {

      let token = mv.keypathToToken(keypath)
      let keypath2 = mv.tokenToKeypath(token)
      assert.equal(keypath, keypath2, "We pack and unpack the keypath correctly")
      
      assert.equal(await instance.exists.call(token), true, "We get the right result for existence of " + keypath)
    }

  })

  it("should work for this particular token value", async function() {
    let instance = await MacroverseExistenceChecker.deployed()
    
    let token = '2981514173051169324652112348446727'

    let keypath = mv.tokenToKeypath(token)
    assert.equal(keypath, '0.0.0.0.0.-1.7.2.2.2', "Token decodes to the correct keypath")

    assert.equal(await instance.exists.call(token), true, "We get the right result for existence of " + keypath)
  })

  // TODO: we could check for rejecting queries with below the minimum balance,
  // but I can't seem to write a test that doesn't hang.

  it("should say that the corner sectors exist and the past-the-corner sectors don't", async function() {
    let instance = await MacroverseExistenceChecker.deployed()

    for (let corner of [
        [10000, 10000, 10000],
        [10000, 10000, -10000],
        [10000, -10000, 10000],
        [10000, -10000, -10000],
        [-10000, 10000, 10000],
        [-10000, 10000, -10000],
        [-10000, -10000, 10000],
        [-10000, -10000, -10000]]) {


        {
            assert.equal(await instance.sectorExists.call(corner[0], corner[1], corner[2]), true, "We get the right result checking manually")

            let keypath = corner[0] + '.' + corner[1] + '.' + corner[2]
            let token = mv.keypathToToken(keypath)
            let keypath2 = mv.tokenToKeypath(token)
            assert.equal(keypath, keypath2, "We pack and unpack the keypath correctly")

            assert.equal(await instance.exists.call(mv.keypathToToken(corner[0] + '.' + corner[1] + '.' + corner[2])), true, "We get the right result checking by token")
        }

        for (let dim of [0, 1, 2]) {
            let outside = [corner[0], corner[1], corner[2]]

            outside[dim] = outside[dim] + outside[dim]/10000

            assert.equal(await instance.sectorExists.call(outside[0], outside[1], outside[2]), false, "We get the right result checking manually")
            
            let keypath = outside[0] + '.' + outside[1] + '.' + outside[2]
            let token = mv.keypathToToken(keypath)
            let keypath2 = mv.tokenToKeypath(token)
            assert.equal(keypath, keypath2, "We pack and unpack the keypath correctly") 
            
            assert.equal(await instance.exists.call(token), false, "We get the right result checking by token")
        }

    }
  })

  it("should say that a particulat plot of land we use in other tests exists", async function() {
    let instance = await MacroverseExistenceChecker.deployed()

    let keypath = '0.0.0.0.0.-1.7.2.2.2'
    let token = mv.keypathToToken(keypath)
    let keypath2 = mv.tokenToKeypath(token)
    assert.equal(keypath, keypath2, "We pack and unpack the keypath correctly") 

    assert.equal(await instance.exists.call(token), true, "We get the right result checking by token")
  })

  
})
