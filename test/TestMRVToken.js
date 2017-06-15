var MRVToken = artifacts.require("MRVToken");

contract('MRVToken', function(accounts) {
  it("should pay 5000 MRV per ETH", async function() {
    let instance = await MRVToken.deployed();
    
    var account_one = accounts[0];
    
    // Buy tokens
    await instance.sendTransaction({from: account_one, value: web3.toWei(1, "ether")})
    
    // See if we got them
    assert.equal((await instance.balanceOf.call(account_one)).toNumber(), web3.toWei(5000, "ether"), "the correct number of tokens are issued")
    
  });
});