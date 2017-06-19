let MinimumBalanceAccessControl = artifacts.require("MinimumBalanceAccessControl");

contract('MinimumBalanceAccessControl', function(accounts) {
  it("should reject queries for addresses with zero balance", async function() {
    let instance = await MinimumBalanceAccessControl.deployed()
    
    assert.equal(await instance.allowQuery.call(accounts[0], accounts[0]), false, "Query from empty account is rejected")
    
  })
})