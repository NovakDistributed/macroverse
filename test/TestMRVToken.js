var MRVToken = artifacts.require("MRVToken");

// We need a function to advance time
function advanceTime(minutes) {
  return new Promise(function (resolve, reject) {
    web3.currentProvider.sendAsync({
      jsonrpc: "2.0",
      method: "evm_increaseTime",
      params: [60 * minutes],
      id: new Date().getTime()
    }, function(err, result) {
      if (err) {
        reject(err)
      } else {
        resolve(result)
      }
    })
  })
}

contract('MRVToken', function(accounts) {
  it("should start inactive", async function() {
    let instance = await MRVToken.deployed();
    
    assert.equal((await instance.isCrowdsaleActive.call()), false, "The crowdsale is initially not started")
  })
  
  it("should grant 5000 MRV to the beneficiary", async function() {
    let instance = await MRVToken.deployed();
    let account = accounts[0]
    assert.equal((await instance.balanceOf.call(account)).toNumber(), web3.toWei(5000, "ether"), "The beneficiary has 5000 MRV before the crowdsale starts")
  })
  
  it("should reject attempts by random people to start the crowdsale", async function() { 
    let instance = await MRVToken.deployed()
    await instance.openCrowdsale({from: accounts[1]}).then(function() {
      assert.ok(false, "Started crowdsale")
    }).catch(function() {
      assert.ok(true, "Did not start crowdsale")
    })
    assert.equal(await instance.isCrowdsaleActive.call(), false, "The crowdsale does not start")
  })
  
  it("should allow the crowdsale to start", async function() { 
    let instance = await MRVToken.deployed()
    
    // DON'T use .call(). .call() confusingly runs things locally, while just () actually sends them.
    await instance.openCrowdsale()

    assert.equal(await instance.isCrowdsaleActive.call(), true, "The crowdsale starts")

  })
  
  it("should reject attempts by random people to stop the crowdsale", async function() { 
    let instance = await MRVToken.deployed()
    await instance.closeCrowdsale({from: accounts[1]}).then(function() {
      assert.ok(false, "Stopped crowdsale")
    }).catch(function() {
      assert.ok(true, "Did not stop crowdsale")
    })
    assert.equal(await instance.isCrowdsaleActive.call(), true, "The crowdsale does not stop")
  })
  
  it("should allow the crowdsale to stop", async function() {
     let instance = await MRVToken.deployed()
     
     await instance.closeCrowdsale()
     
     assert.equal(await instance.isCrowdsaleActive.call(), false, "The crowdsale stops")
  })
  
  it("should reject attempts to restart the crowdsale", async function() { 
    let instance = await MRVToken.deployed()
    await instance.openCrowdsale().then(function() {
      assert.ok(false, "Started crowdsale")
    }).catch(function() {
      assert.ok(true, "Did not start crowdsale")
    })
    assert.equal(await instance.isCrowdsaleActive.call(), false, "The crowdsale does not restart")
  })
  
})

contract('MRVToken', function(accounts) {
  it("should start with the start timer unset", async function() {
    let instance = await MRVToken.deployed()
    assert.equal(await instance.openTimer.call(), 0, "Open timer is not set")
  })
  
  it("should not let random people set the start timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleOpenTimerFor(30, {from: accounts[1]}).then(function() {
      assert.ok(false, "Set timer")
    }).catch(function() {
      assert.ok(true, "Did not set timer")
    })
    
    assert.equal(await instance.openTimer.call(), 0, "Open timer is not set")
  })
  
  it("should let the owner set the start timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleOpenTimerFor(30)
    
    assert.isAtLeast(await instance.openTimer.call(), 1, "Open timer is set")
  })
  
  it("should not let random people unset the start timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.clearCrowdsaleOpenTimer({from: accounts[1]}).then(function() {
      assert.ok(false, "Unset timer")
    }).catch(function() {
      assert.ok(true, "Did not unset timer")
    })
    
    assert.isAtLeast(await instance.openTimer.call(), 1, "Open timer is set")
  })
  
  it("should let the owner unset the start timer before it elapses", async function() {
    let instance = await MRVToken.deployed()
    
    // Go ahead some time
    await advanceTime(29)
    
    await instance.clearCrowdsaleOpenTimer()
    
    assert.equal(await instance.openTimer.call(), 0, "Open timer is not set")
    
  })
  
  it("should say the crowdsale is still closed", async function() {
    let instance = await MRVToken.deployed()
    assert.equal((await instance.isCrowdsaleActive.call()), false, "The crowdsale is still not started")
  })
  
  it("should let the owner set the start timer again", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleOpenTimerFor(50)
    
    assert.isAtLeast(await instance.openTimer.call(), 1, "Open timer is set")
  })
  
  it("should not let the owner unset the start timer after it elapses", async function() {
    let instance = await MRVToken.deployed()
    
    
    // Go ahead some time
    await advanceTime(51)
    
    await instance.clearCrowdsaleOpenTimer().then(function() {
      assert.ok(false, "Unset timer")
    }).catch(function() {
      assert.ok(true, "Did not unset timer")
    })
    
   assert.isAtLeast(await instance.openTimer.call(), 1, "Open timer is set")
    
  })
  
  it("should say the crowdsale is open now that the timer has elapsed", async function() {
    let instance = await MRVToken.deployed()
    assert.equal((await instance.isCrowdsaleActive.call()), true, "The crowdsale is now open")

    // Buy tokens
    await instance.sendTransaction({from: accounts[1], value: web3.toWei(1, "ether")})
    
    // See if we got them
    assert.isAtLeast((await instance.balanceOf.call(accounts[1])).toNumber(), web3.toWei(5000, "ether"), "Tokens can be bought")
  })
  
  it("should not let random people set the stop timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleCloseTimerFor(30, {from: accounts[1]}).then(function() {
      assert.ok(false, "Set timer")
    }).catch(function() {
      assert.ok(true, "Did not set timer")
    })
    
    assert.equal(await instance.closeTimer.call(), 0, "Close timer is not set")
  })
  
  it("should let the owner set the stop timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleCloseTimerFor(30)
    
    assert.isAtLeast(await instance.closeTimer.call(), 1, "Close timer is set")
  })
  
  it("should not let random people unset the stop timer", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.clearCrowdsaleCloseTimer({from: accounts[1]}).then(function() {
      assert.ok(false, "Unset timer")
    }).catch(function() {
      assert.ok(true, "Did not unset timer")
    })
    
    assert.isAtLeast(await instance.closeTimer.call(), 1, "Close timer is set")
  })
  
  it("should let the owner unset the stop timer before it ends", async function() {
    let instance = await MRVToken.deployed()
    
    // Go ahead some time
    await advanceTime(29)
    
    await instance.clearCrowdsaleCloseTimer()
    
    assert.equal(await instance.closeTimer.call(), 0, "Close timer is not set")
  })
  
  it("should say the crowdsale is still open", async function() {
    let instance = await MRVToken.deployed()
    assert.equal((await instance.isCrowdsaleActive.call()), true, "The crowdsale is still open")
  })
  
  it("should let the owner start the stop timer again", async function() {
    let instance = await MRVToken.deployed()
    
    await instance.setCrowdsaleCloseTimerFor(50)
    
    assert.isAtLeast(await instance.closeTimer.call(), 1, "Close timer is set")
  })
  
  it("should reject contributions after the stop timer elapses", async function() {
    let instance = await MRVToken.deployed()
    
    // Go ahead some time
    await advanceTime(51)
    
    // Fail to get tokens
    await instance.sendTransaction({from: accounts[2], value: web3.toWei(1, "ether")}).then(function () {
      assert.ok(false, "Successfully bought after close")
    }).catch(async function () {
      assert.equal((await instance.balanceOf.call(accounts[2])).toNumber(), 0, "Failed to buy after close")
    })
    
  })
  
  it("should say the crowdsale is over after the stop timer elapses", async function() {
    let instance = await MRVToken.deployed()
    assert.equal((await instance.isCrowdsaleActive.call()), false, "The crowdsale is still not started")
  })
  
  it("should let anyone call the timer check method", async function() {
    let instance = await MRVToken.deployed()

    await instance.checkCloseTimer({from: accounts[2]})
    
    // We can't check the internal closed bool.
  })
})

// New test case, for new contract
contract('MRVToken', function(accounts) {
  
  it("should still start inactive", async function() {
    let instance = await MRVToken.deployed();
    
    assert.equal((await instance.isCrowdsaleActive.call()), false, "The crowdsale is initially not started")
  })
 
  it("should not allow decimals to be changed before the crowdsale starts", async function() {
    let instance = await MRVToken.deployed();
    
    assert.equal((await instance.decimals.call()), 18, "The decimals start at 18")
    
    await instance.setDecimals(30).then(function() {
      assert.ok(false, "Set decimals")
    }).catch(function() {
      assert.ok(true, "Did not set decimals")
    })
    
    assert.equal((await instance.decimals.call()), 18, "The decimals are not changed")
  })
  
  it("should pay 5000 MRV per ETH", async function() {
    
    let instance = await MRVToken.deployed()
    let account = accounts[0]
    
    await instance.openCrowdsale()

    assert.equal(await instance.isCrowdsaleActive.call(), true, "The crowdsale starts")
    
    // We may have some MRV already.
    let initialBalance = (await instance.balanceOf.call(account)).toNumber();
    
    // Buy tokens
    await instance.sendTransaction({from: account, value: web3.toWei(1, "ether")})
    
    // How many MRV do we have now?
    let finalBalance = (await instance.balanceOf.call(account)).toNumber();
    
    // See if we got them
    assert.equal(finalBalance - initialBalance, web3.toWei(5000, "ether"), "The correct number of tokens are issued")
  })
  
  it("should not allow decimals to be changed before the crowdsale ends", async function() {
    let instance = await MRVToken.deployed();
    
    await instance.setDecimals(30).then(function() {
      assert.ok(false, "Set decimals")
    }).catch(function() {
      assert.ok(true, "Did not set decimals")
    })
    
    assert.equal((await instance.decimals.call()), 18, "The decimals are not changed")
  })
  
  it("should allow decimals to be changed after the crowdsale ends", async function() {
    let instance = await MRVToken.deployed();
    
    await instance.closeCrowdsale()
    
    await instance.setDecimals(30)
    
    assert.equal((await instance.decimals.call()), 30, "The decimals are changed")
  })
  
  it("should not allow decimals to be changed by random people", async function() {
    let instance = await MRVToken.deployed();
    
    await instance.setDecimals(22, {from: accounts[1]}).then(function() {
      assert.ok(false, "Set decimals")
    }).catch(function() {
      assert.ok(true, "Did not set decimals")
    })
    
    assert.equal((await instance.decimals.call()), 30, "The decimals are not changed")
  })
  
})

contract('MRVToken', function(accounts) {
  it("should allow buying the max number of tokens, but no more", async function() {
    let instance = await MRVToken.deployed();
    let account = accounts[0]
    
    // We need to lower the max because testrpc only grants us so much ETH
    let CROWDSALE_MAX_TOKENS = 5000
    
    // Set max. Note that this is denominated in WHOLE tokens, not in wei-size units.
    await instance.setMaxSupply(CROWDSALE_MAX_TOKENS)
    
    // Start crowdsale
    await instance.openCrowdsale()
    
    // We may have some MRV already.
    let initialBalance = (await instance.balanceOf.call(account)).toNumber();
    
    // Buy tokens
    await instance.sendTransaction({from: account, value: web3.toWei(CROWDSALE_MAX_TOKENS/5000, "ether")})
    
    // See if we got them
    assert.equal((await instance.balanceOf.call(account)).toNumber() - initialBalance, web3.toWei(CROWDSALE_MAX_TOKENS, "ether"), "All tokens can be issued")
    
    // Fail to get any more
    await instance.sendTransaction({from: account, value: web3.toWei(2/5000, "ether")}).then(function () {
      assert.ok(false, "Successfully bought excess tokens")
    }).catch(async function () {
      assert.equal((await instance.balanceOf.call(account)).toNumber() - initialBalance, web3.toWei(CROWDSALE_MAX_TOKENS, "ether"), "No more tokens than the max can be issued")
    })
    
    
  })
  
})