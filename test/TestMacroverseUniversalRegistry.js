let MacroverseUniversalRegistry = artifacts.require("MacroverseUniversalRegistry");
let MRVToken = artifacts.require("MRVToken");

// Load the Macroverse module JavaScript
let mv = require('../src')

async function assert_throws(promise, message) {
  try {
    await promise
    assert.ok(false, message)
  } catch {
    // OK
  }
}

contract('MacroverseUniversalRegistry', function(accounts) {
  it("should allow committing", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    assert.equal((await mrv.balanceOf.call(accounts[0])).toNumber(), web3.toWei(5000, "ether"), "We start with the expected amount of MRV for the test")
    
    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[0]))

    // Decide what to claim: system 0 of sector 0,0,0
    let to_claim = mv.keypathToToken('0.0.0.0')

    // Generate a **random** nonce.
    // If someone can brute force this they may be able to front run your claim
    let nonce = 0xDEAD 

    // Compute a hash
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    let saw_event = false

    // Watch commit events
    let filter = instance.Commit({}, { fromBlock: 'latest', toBlock: 'latest'})
    filter.watch((error, event_report) => { 
      if (event_report.event == 'Commit' && event_report.args.owner == accounts[0] && event_report.args.hash == data_hash) {
        // We did a commit.
        saw_event = true
      }
      // TODO: For some reason this fires twice with the same event...
    })

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"))

    // Don't care about events after that
    filter.stopWatching();

    assert.equal(saw_event, true, "We got the expected commitment hash in an event")

    // We should have less money now
    assert.equal((await mrv.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4000, "ether"), "We lost the expected amount of MRV to the deposit")

  })

  it("should prohibit revealing too soon", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    // Remember our commitment from the last test?
    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD
    
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed too early")

    let balance = (await instance.balanceOf(accounts[0])).toNumber();
    assert.equal(balance, 0, "Claimant got a token anyway")

    // ownerOf throws for nonexistent tokens, it doesn't say they're owned by nobody.
    assert.equal(await instance.exists(to_claim), false, "Token shouldn't exist after too-early reveal")
  })

  it("should prohibit revealing at the right time but with too low a deposit", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    // Remember our commitment from the last test?
    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD
    
    // Advance time for 2 days which should be enough
    await mv.advanceTime(60 * 24 * 2)

    assert.equal(await instance.exists(to_claim), false, "Token exists too early")

    // We're also going to test price adjustments

    let saw_event = false
    let new_price = undefined

    // Watch price adjust events
    let filter = instance.DepositScaleChange({}, { fromBlock: 'latest', toBlock: 'latest' })
    filter.watch((error, event_report) => {
      if (event_report.event == 'DepositScaleChange') {
        // Remember we saw the change
        saw_event = true
        // And what we changed to
        new_price = event_report.args.new_min_system_deposit_in_atomic_units.toNumber()
      }
    })

    // Adjust the price up
    await instance.setMinimumSystemDeposit(web3.toWei(1001, "ether"))

    filter.stopWatching()

    assert.equal(saw_event, true, "We got the first expected price change event")
    assert.equal(new_price, web3.toWei(1001, "ether"), "We got the first expected new price")

    await assert_throws(instance.reveal(to_claim, nonce), "Revealed with too small deposit")

    // Adjust the price back down
    await instance.setMinimumSystemDeposit(web3.toWei(1000, "ether"))
    // TODO: somehow this doesn't fire the event right away. It comes in later.

    let balance = (await instance.balanceOf(accounts[0])).toNumber();
    assert.equal(balance, 0, "Claimant got a token anyway")

    // ownerOf throws for nonexistent tokens, it doesn't say they're owned by nobody.

    assert.equal(await instance.exists(to_claim), false, "Token shouldn't exist after too-cheap reveal")
  })

  it("should allow revealing at the right time", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD

    assert.equal(await instance.exists(to_claim), false, "Token exists too early");
    
    // Time has already been advanced

    // Wait for the reveal to try to happen
    await instance.reveal(to_claim, nonce)

    // Get the owner of the token we got
    let token_owner = await instance.ownerOf(to_claim)

    // Make sure we own the token
    assert.equal(token_owner, accounts[0], "Token not owned by claimant");
    assert.equal(await instance.exists(to_claim), true, "Token not created");
  })

  it("should prohibit revealing for an already owned thing", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[0]))

    // Use the same token as the last test
    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD2 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)
    
    let saw_event = false

    // Watch commit events
    let filter = instance.Commit({}, { fromBlock: 'latest', toBlock: 'latest'})
    filter.watch((error, event_report) => { 
      if (event_report.event == 'Commit' && event_report.args.owner == accounts[0] && event_report.args.hash == data_hash) {
        // Remember we saw the hash
        saw_event = true
      }
    })

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"))

    // Don't care about events after that
    filter.stopWatching()

    assert.equal(saw_event, true, "We got the expected commitment hash in an event")

    assert.equal((await mrv.balanceOf.call(accounts[0])).toNumber(), web3.toWei(3000, "ether"), "We lost the expected amount of MRV to the deposit")

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed conflicting claim")
  })

  it("should prohibit canceling commitments made by others", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    // We don't even have a way to address other people's commitments unless we can collide hashes.
    // But make a half-assed attempt.
    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD2 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    await assert_throws(instance.cancel(data_hash, {from: accounts[1]}), "Canceled someone's claim")
  })

  it("should allow canceling your own commitment that you failed to reveal", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    let to_claim = mv.keypathToToken('0.0.0.0')
    let nonce = 0xDEAD2 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    await instance.cancel(data_hash)

    assert.ok(true, "Cancel transaction goes through")

    assert.equal((await mrv.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4000, "ether"), "Our deposit was refunded")
    
  })

  it("should prohibit revealing expired commitments", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Try to get some land
    let to_claim = mv.keypathToToken('0.1.2.0.0.-1.7.2.2.2')
    let nonce = 0xDEADBEEF 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)
    
    let saw_event = false

    // Watch commit events
    let filter = instance.Commit({}, { fromBlock: 'latest', toBlock: 'latest'})
    filter.watch((error, event_report) => {
      if (event_report.event == 'Commit' && event_report.args.owner == accounts[0] && event_report.args.hash == data_hash) {
        // Remember we saw the hash
        saw_event = true
      }
    })

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"))

    // Don't care about events after that
    filter.stopWatching()

    assert.equal(saw_event, true, "We got the expected commitment hash in an event")

    // Advance time for 20 days which should be enough
    await mv.advanceTime(60 * 24 * 20)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed expired claim")

    assert.equal(await instance.exists(to_claim), false, "Token shouldn't exist after expired reveal")

    // Now cancel the commitment
    await instance.cancel(data_hash)
  })

  it("should prohibit revealing for a child token of a token owned by someone else", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Get and approve the deposit tokens (plus 100 to pass the minimum balance control)
    await mrv.transfer(accounts[1], web3.toWei(1100, "ether"))
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[1]), {from: accounts[1]})

    // Try to get a child (some land on a planet) of the token (system) we already claimed for account 0
    let to_claim = mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2')
    let nonce = 0xDEADBEEF 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)
    
    let saw_event = false

    // Watch commit events
    let filter = instance.Commit({}, { fromBlock: 'latest', toBlock: 'latest'})
    filter.watch((error, event_report) => {
      if (event_report.event == 'Commit' && event_report.args.owner == accounts[1] && event_report.args.hash == data_hash) {
        // Remember we saw the hash
        saw_event = true
      }
    })

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"), {from: accounts[1]})

    // Don't care about events after that
    filter.stopWatching()

    assert.equal(saw_event, true, "We got the expected commitment hash in an event")

    assert.equal((await mrv.balanceOf.call(accounts[1])).toNumber(), web3.toWei(100, "ether"), "We lost the expected amount of MRV to the deposit")

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed unauthorized subclaim")

    // We leave the commitment outstanding for a later test
  })

  it("should prohibit releasing other people's things", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let token = mv.keypathToToken('0.0.0.0')

    await assert_throws(instance.release(token, {from: accounts[1]}), "Released someone's claim")
    
  })

  it("should prohibit transfering other people's things", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let token = mv.keypathToToken('0.0.0.0')

    // ERC-721 weirdly has no transfer, only transferFrom. Probably because
    // that's easier to prove correctness for by inspection.

    await assert_throws(instance.transferFrom(accounts[0], accounts[1], token, {from: accounts[1]}), "Moved someone's token")
    
  })

  it("should allow transfering owned things", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let token = mv.keypathToToken('0.0.0.0')

    await instance.transferFrom(accounts[0], accounts[1], token, {from: accounts[0]})

    // Get the owner of the token
    let token_owner = await instance.ownerOf(token)

    // Make sure we own the token
    assert.equal(token_owner, accounts[1], "Token owned by recipient");
    
  })

  it("should permit revealing for a child token of a token owned by us", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Try to get a child (some land on a planet) of the token (system) we now own
    let to_claim = mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2')
    let nonce = 0xDEADBEEF 

    // Now try revealing. It should work because we own the parent token and it isn't land.
    await instance.reveal(to_claim, nonce, {from: accounts[1]})

    // Get the owner of the token'
    let token_owner = await instance.ownerOf(to_claim)

    // Make sure we own the token
    assert.equal(token_owner, accounts[1], "Token owned by recipient");
  })

  it("should allow releasing owned things", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Record our startign balance to check for a refund
    let startBalance = await mrv.balanceOf.call(accounts[1])

    let token = mv.keypathToToken('0.0.0.0')
    let released

    // Watch release events
    let filter = instance.Release({}, { fromBlock: 'latest', toBlock: 'latest'})
    filter.watch((error, event_report) => { 
      if (event_report.event == 'Release' && event_report.args.former_owner == accounts[1]) {
        // We did a release.
        // Remember the token we released
        released = event_report.args.token.toNumber()
      }

    })

    await instance.release(token, {from: accounts[1]})

    filter.stopWatching();

    assert.equal(released, token, "Token not released")

    // We should have less money now
    assert.equal((await mrv.balanceOf.call(accounts[1])).toNumber(), startBalance.plus(web3.toWei(1000, "ether")), "We got the expected amount of MRV back from the deposit")
  })

  it("should prohibit revealing for a child token of owned land", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[1]), {from: accounts[1]})

    // This is a child of the land token we have been working with
    let to_claim = mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2.1')
    let nonce = 0xDEADBEEF55 
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)
    
    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"), {from: accounts[1]})

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed land subplot")

    // Clean up
    await instance.cancel(data_hash, {from: accounts[1]})
  })

  it("should prohibit revealing for a parent token of owned land", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[1]), {from: accounts[1]})

    // This is a parent of the land token we have been working with
    let to_claim = mv.keypathToToken('0.0.0.0.0.-1.7.2.2')
    let nonce = 0xDEADBEEF88
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"), {from: accounts[1]})

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed land superplot")

    // Clean up
    await instance.cancel(data_hash, {from: accounts[1]})
  })

  it("should permit subdividing land", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let parent_token = mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2')
    let child_tokens = []
    for (let i = 0; i < 4; i++) {
        child_tokens.push(mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2.' + i))
    }

    // Land min deposits are pretty small, and we put 1000 MRV in here, so we should be OK to subdivide for a while.
    
    // Subdivide the land
    await instance.subdivideLand(parent_token, 0, {from: accounts[1]})

    for (let child of child_tokens) {
      // Get the owner of the token
      let token_owner = await instance.ownerOf(child)

      // Make sure we own the token
      assert.equal(token_owner, accounts[1], "Child token owned by subdivider");
    }
  })

  it("should permit merging land", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    let parent_token = mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2')
    let child_tokens = []
    for (let i = 0; i < 4; i++) {
        child_tokens.push(mv.keypathToToken('0.0.0.0.0.-1.7.2.2.2.' + i))
    }

    // Merge the land
    await instance.combineLand(child_tokens[0], child_tokens[1], child_tokens[2], child_tokens[3], 0, {from: accounts[1]})

    // Get the owner of the token
    let token_owner = await instance.ownerOf(parent_token)

    // Make sure we own the token
    assert.equal(token_owner, accounts[1], "Parent token owned by merger");
  })

  it("should prohibit revealing for land on an asteroid belt", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[1]), {from: accounts[1]})

    // This is land on an asteroid belt
    let to_claim = mv.keypathToToken('0.0.0.28.2.-1.5.2.1.2')
    let nonce = 0xDEADBEEF89
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"), {from: accounts[1]})

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed asteroid belt land")

    // Clean up
    await instance.cancel(data_hash, {from: accounts[1]})
  })

  it("should prohibit revealing for land on a ring", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[1]), {from: accounts[1]})

    // This is land on a ring
    let to_claim = mv.keypathToToken('0.0.0.16.5.0.1.2.3.2.1.0')
    let nonce = 0xDEADBEEF90
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"), {from: accounts[1]})

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed ring land")

    // Clean up
    await instance.cancel(data_hash, {from: accounts[1]})
  })

  it("should prohibit revealing for a sector", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()

    // Approve the deposit tokens
    await mrv.approve(instance.address, await mrv.balanceOf.call(accounts[0]))

    // This is land on a ring
    let to_claim = mv.keypathToToken('0.0.0')
    let nonce = 0xDEADBEEF9001
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    // Commit for it with loads of money
    await instance.commit(data_hash, await mrv.balanceOf.call(accounts[0]))

    // Advance time for 2 days to mature the commitment
    await mv.advanceTime(60 * 24 * 2)

    // Now try revealing. It should fail.
    await assert_throws(instance.reveal(to_claim, nonce), "Revealed entire sector")

    // Clean up
    await instance.cancel(data_hash)
  })

  it("should report a sensible set of minimum creation deposits", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    
    let star_keypath = '0.0.0.0'
    let star_cost = (await instance.getMinDepositToCreate(mv.keypathToToken(star_keypath))).toNumber()
    console.log('Star cost: ' + web3.fromWei(star_cost, 'ether') + ' MRV')
    assert.equal(star_cost, web3.toWei(1000, "ether"), "star cost is incorrect")

    let planet_keypath = star_keypath + '.0'
    let planet_cost = (await instance.getMinDepositToCreate(mv.keypathToToken(planet_keypath))).toNumber()
    console.log('Planet cost: ' + web3.fromWei(planet_cost, 'ether') + ' MRV')
    assert.equal(planet_cost, web3.toWei(100, "ether"), "planet cost is incorrect")

    let moon_keypath = planet_keypath + '.0'
    let moon_cost = (await instance.getMinDepositToCreate(mv.keypathToToken(moon_keypath))).toNumber()
    console.log('Moon cost: ' + web3.fromWei(moon_cost, 'ether') + ' MRV')
    assert.equal(moon_cost, web3.toWei(25, "ether"), "moon cost is incorrect")

    for (let i = 1; i < 28; i++) {
      // Try all the land subdivisions with at least one land number
      let planet_land_keypath = planet_keypath + '.-1'
      for(let j = 0; j < i; j++) {
        planet_land_keypath = planet_land_keypath + '.0'
      }

      // Compute area in Earth acres (126 billion overall)
      let earth_total_acres = 126000000000

      let planet_land_cost = (await instance.getMinDepositToCreate(mv.keypathToToken(planet_land_keypath))).toNumber()
      let planet_land_area = earth_total_acres / 2 / Math.pow(4, i)
      console.log('Planet land level ' + i + ' cost: ' +
        web3.fromWei(planet_land_cost, 'ether') + ' MRV @ ' + planet_land_area + ' Earth-acres or ' +
        web3.fromWei(planet_land_cost/planet_land_area, "ether") + " MRV per acre on Earth")
      assert.equal(planet_land_cost, Math.trunc(web3.toWei(100 / Math.pow(2, i + 1)), "ether"), "planet land cost is incorrect")
      
      let moon_land_keypath = moon_keypath
      for(let j = 0; j < i; j++) {
        moon_land_keypath = moon_land_keypath + '.0'
      }

      let moon_land_cost = (await instance.getMinDepositToCreate(mv.keypathToToken(moon_land_keypath))).toNumber()
      console.log('Moon land level ' + i + ' cost: ' +
        web3.fromWei(moon_land_cost, 'ether') + ' MRV')
      assert.equal(moon_land_cost, Math.trunc(web3.toWei(25 / Math.pow(2, i + 1)), "ether"), "moon land cost is incorrect")
    }

    
  })


})
