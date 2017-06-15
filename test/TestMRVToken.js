var MRVToken = artifacts.require("MRVToken");

contract('MRVToken', function(accounts) {
  it("should start inactive", async function() {
    let instance = await MRVToken.deployed();
    
    let account_one = accounts[0]
    
    assert.equal((await instance.isCrowdsaleActive.call()), false, "the crowdsale is initially not started")
  })
  
  it("should allow the crowdsale to start", async function() { 
    // Start crowdsale
    // Note that we can't await the isCrowdsaleActive result for some reason; we have to use then.
    // This may be a bug in web3 or Truffle
    let instance = await MRVToken.deployed()
    
    // DON'T use .call(). .call() confusingly runs things locally, while just () actually sends them.
    await instance.startCrowdsale()

    assert.equal(await instance.isCrowdsaleActive.call(), true, "the crowdsale starts")

  })
})

// New test case, for new contract
contract('MRVToken', function(accounts) {
  
  it("should still start inactive", async function() {
    let instance = await MRVToken.deployed();
    
    assert.equal((await instance.isCrowdsaleActive.call()), false, "the crowdsale is initially not started")
  })
 
  
  it("should pay 5000 MRV per ETH", async function() {
    
    let instance = await MRVToken.deployed()
    let account_one = accounts[0]
    
    await instance.startCrowdsale()

    assert.equal(await instance.isCrowdsaleActive.call(), true, "the crowdsale starts")
    
    
    // Buy tokens
    await instance.sendTransaction({from: account_one, value: web3.toWei(1, "ether")})
    
    // See if we got them
    assert.equal((await instance.balanceOf.call(account_one)).toNumber(), web3.toWei(5000, "ether"), "the correct number of tokens are issued")
  })
})

contract('MRVToken', function(accounts) {
  it("should allow buying the max number of tokens, but no more", async function() {
    let instance = await MRVToken.deployed();
    let account_one = accounts[0]
    
    // We need to lower the max because testrpc only grants us so much ETH
    let MAX_TOKENS = 5000
    
    // Set max. Note that this is denominated in WHOLE tokens, not in wei-size units.
    await instance.setMaxSupply(MAX_TOKENS)
    
    // Start crowdsale
    await instance.startCrowdsale()
      
    // Buy tokens
    await instance.sendTransaction({from: account_one, value: web3.toWei(MAX_TOKENS/5000, "ether")})
    
    // See if we got them
    assert.equal((await instance.balanceOf.call(account_one)).toNumber(), web3.toWei(MAX_TOKENS, "ether"), "all tokens can be issued")
    
    // Fail to get any more
    await instance.sendTransaction({from: account_one, value: web3.toWei(2/5000, "ether")}).then(function () {
      assert.ok(false, "successfully bought excess tokens")
    }).catch(async function () {
      assert.equal((await instance.balanceOf.call(account_one)).toNumber(), web3.toWei(MAX_TOKENS, "ether"), "no more tokens than the max can be issued")
    })
    
    
  })
  
})