let MacroverseStarRegistry = artifacts.require("MacroverseStarRegistry");
let MRVToken = artifacts.require("MRVToken");

contract('MacroverseStarRegistry', function(accounts) {
  it("should not allow claiming with actually possible funds", async function() {
    let instance = await MacroverseStarRegistry.deployed()
    let token = await MRVToken.deployed()
    
    // Approve all the funds.
    // Don't do any more approvals in the test because the token requires us
    // to reduce approved amount to 0 defore approving any more.
    await token.approve(MacroverseStarRegistry.address, await token.balanceOf.call(accounts[0]))
    
    await instance.claimOwnership("COOL_STAR_9000", await token.balanceOf.call(accounts[0]) ).then(function () {
      assert.ok(false, "Successfully claimed star on deactivated registry")
    }).catch(async function () {
      assert.ok(true, "Failed to claim star on deactivated registry")
    })
    
    assert.equal(await instance.ownerOf.call("COOL_STAR_9000"), 0, "The star is still unowned")
    
  })
})
