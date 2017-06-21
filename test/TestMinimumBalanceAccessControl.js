let MinimumBalanceAccessControl = artifacts.require("MinimumBalanceAccessControl");

contract('MinimumBalanceAccessControl', function(accounts) {
  
  // Remember that we deployed the MRVToken with the beneficiary as account 0, granting it some tokens.
  
  it("should reject queries for addresses with zero balance", async function() {
    let instance = await MinimumBalanceAccessControl.deployed()
    
    assert.equal(await instance.allowQuery.call(accounts[1], accounts[1]), false, "Query from empty account is rejected")
    
  })
  
  it("should allow queries for addresses with sufficient balance", async function() {
    let instance = await MinimumBalanceAccessControl.deployed()
    
    assert.equal(await instance.allowQuery.call(accounts[0], accounts[0]), true, "Query from full account is accepted")
    
  })
})