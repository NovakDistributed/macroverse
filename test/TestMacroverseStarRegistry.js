let MacroverseStarRegistry = artifacts.require("MacroverseStarRegistry");
let MRVToken = artifacts.require("MRVToken");

contract('MacroverseStarRegistry', function(accounts) {
  
  
  it("should not allow claiming with sufficient, un-approved funds", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(5000, "ether"), "We start with the expected amount of MRV for the test")
    
    await instance.claimOwnership("COOL_STAR_9000", web3.toWei(1000, "ether")).then(function () {
      assert.ok(false, "Successfully claimed star without approving funds")
    }).catch(async function () {
      assert.ok(true, "Failed to claim star without approving funds")
    })
    
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), 0, "The star is still unowned")
    
  })
  
  it("should not allow claiming without sufficient funds", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    // Approve a lot of funds
    await token.approve(MacroverseStarRegistry.address, web3.toWei(10000, "ether"))
    
    await instance.claimOwnership("COOL_STAR_9000", web3.toWei(10000, "ether")).then(function () {
      assert.ok(false, "Successfully claimed star without funds for deposit")
    }).catch(async function () {
      assert.ok(true, "Failed to claim star without funds for deposit")
    })
    
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), 0, "The star is still unowned")
    
  })
  
  it("should not allow claiming with a too-small deposit", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    assert.equal((await instance.minDepositInAtomicUnits.call()).toNumber(), web3.toWei(1000, "ether"), "The minimum deposit is as expected for the test")
    
    // Approve a lot of funds
    await token.approve(MacroverseStarRegistry.address, web3.toWei(10000, "ether"))
    
    await instance.claimOwnership("COOL_STAR_9000", web3.toWei(999, "ether")).then(function () {
      assert.ok(false, "Successfully claimed star with too-small deposit")
    }).catch(async function () {
      assert.ok(true, "Failed to claim star with too-small deposit")
    })
    
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), 0, "The star is still unowned")
    
  })
  
  it("should allow the minimum deposit to be changed", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    await instance.setMinimumDeposit(web3.toWei(12345, "ether"))
    assert.equal((await instance.minDepositInAtomicUnits.call(accounts[0])).toNumber(), web3.toWei(12345, "ether"), "The minimum deposit can be raised")
    
    await instance.setMinimumDeposit(web3.toWei(999, "ether"))
    assert.equal((await instance.minDepositInAtomicUnits.call(accounts[0])).toNumber(), web3.toWei(999, "ether"), "The minimum deposit can be lowered")
    
  })
  
  it("should allow claiming with a sufficient approved deposit", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    // Approve a lot of funds
    await token.approve(MacroverseStarRegistry.address, web3.toWei(10000, "ether"))
    
    // Now the min deposit is 999 MRV, from the last test
    await instance.claimOwnership("COOL_STAR_9000", web3.toWei(999, "ether"))
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), accounts[0], "The star is now owned by us")
    
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4001, "ether"), "The correct number of MRV tokens are taken from us")
    assert.equal((await token.balanceOf.call(instance.address)).toNumber(), web3.toWei(999, "ether"), "The correct number of MRV tokens are now held by the contract")
    
  })
  
  it("should not allow claiming things already owned", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()

    // Approve a lot of funds
    await token.approve(MacroverseStarRegistry.address, web3.toWei(10000, "ether"))
    
    await instance.claimOwnership("COOL_STAR_9000", web3.toWei(999, "ether")).then(function () {
      assert.ok(false, "Successfully claimed star that is already claimed")
    }).catch(async function () {
      assert.ok(true, "Failed to claim star that is already claimed")
    })
  })
  
  it("should allow transfer of owned things", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    
    await instance.transferOwnership("COOL_STAR_9000", accounts[1])
    
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), accounts[1], "The star is now owned by the other account")
    
  })
  
  it("should allow misplaced tokens to not be stuck", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4001, "ether"), "We start with the right MRV token balance")
    
    await token.transfer(instance.address, web3.toWei(5, "ether"))
    
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(3996, "ether"), "We can send extra to the contract")
    
    await instance.reclaimToken(token.address)
    
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4001, "ether"), "We get exactly the excess MRV back")
    
  })
  
  it("should not allow abdication of ownership on other people's stuff", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    
    await instance.abdicateOwnership("COOL_STAR_9000").then(function () {
      assert.ok(false, "Successfully abdicated someone else's star")
    }).catch(async function () {
      assert.ok(true, "Failed to abdicate someone else's star")
    })
    
  })
  
  it("should allow abdication of ownership and return the initial deposit", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    await instance.abdicateOwnership("COOL_STAR_9000", {from: accounts[1]})
    
    assert.equal((await token.balanceOf.call(accounts[1])).toNumber(), web3.toWei(999, "ether"), "The correct number of MRV tokens are returned")
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4001, "ether"), "The initial claimant doesn't have them")
    assert.equal((await token.balanceOf.call(instance.address)).toNumber(), web3.toWei(0, "ether"), "The star registry no longer has them")
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), 0, "The star is now unowned")
  })
  
})