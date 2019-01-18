let MacroverseUniversalRegistry = artifacts.require("MacroverseUniversalRegistry");
let MRVToken = artifacts.require("MRVToken");

// Load the Macroverse module JavaScript
let mv = require('../src')

contract('MacroverseUniversalRegistry', function(accounts) {
  it("should allow committing", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let token = await MRVToken.deployed()

    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(5000, "ether"), "We start with the expected amount of MRV for the test")
    
    // Approve the deposit tokens
    await token.approve(instance.address, await token.balanceOf.call(accounts[0]))

    // Decide what to claim.
    // TODO: Write token packing in Javascript
    let to_claim = 12345

    // Generate a **random** nonce.
    // If someone can brute force this they may be able to front run your claim
    let nonce = 0xDEAD 

    // Compute a hash
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    var commitment_id;

    // Watch commit events
    let filter = instance.Commit({}, { fromBlock: 0, toBlock: 'latest'})
    filter.watch((error, event_report) => { 
      if (event_report.event == 'Commit' && event_report.args.owner == accounts[0]) {
        // We did a commit.
        // TODO: Distinguish it from any other attempt we are simultaneously making to commit.
        // Include the hash in the event?
        // Remember the ID we observed
        commitment_id = event_report.args.commitment_id.toNumber()
      }

      // TODO: For some reason this fires twice with the same event...
    })

    // Commit for it
    await instance.commit(data_hash, web3.toWei(1000, "ether"))

    // Don't care about events after that
    filter.stopWatching();

    // We can't get the ID because we can't get the return value of a real transaction because reasons...
    // We have to watch the events for it

    assert.equal(commitment_id, 0, "We got the expected commitment ID in an event")

    // We should have less money now
    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(4000, "ether"), "We lost the expected amount of MRV to the deposit")

  })
})
