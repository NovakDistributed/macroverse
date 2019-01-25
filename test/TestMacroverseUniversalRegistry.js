let MacroverseUniversalRegistry = artifacts.require("MacroverseUniversalRegistry");
let MRVToken = artifacts.require("MRVToken");

// Load the Macroverse module JavaScript
let mv = require('../src')

// We need a function to advance time
// TODO: deduplicate with the crowsdale test and put in a test utils module somewhere
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

contract('MacroverseUniversalRegistry', function(accounts) {
  it("should allow committing", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()
    let token = await MRVToken.deployed()

    assert.equal((await token.balanceOf.call(accounts[0])).toNumber(), web3.toWei(5000, "ether"), "We start with the expected amount of MRV for the test")
    
    // Approve the deposit tokens
    await token.approve(instance.address, await token.balanceOf.call(accounts[0]))

    // Decide what to claim.
    // TODO: Write token packing in Javascript
    // This happens to be a real token: system 0 of sector 0,0,0
    let to_claim = 0x1

    // Generate a **random** nonce.
    // If someone can brute force this they may be able to front run your claim
    let nonce = 0xDEAD 

    // Compute a hash
    let data_hash = mv.hashTokenAndNonce(to_claim, nonce)

    let commitment_id;

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

  it("should prohibit revealing too soon", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    // Remember our commitment from the last test?
    let to_claim = 0x1
    let nonce = 0xDEAD
    let commitment_id = 0

    await instance.reveal(commitment_id, to_claim, nonce).then(function() {
      assert.ok(false, "Revealed too early")
    }).catch(function() {
      assert.ok(true, "Early reveal rejected")
    })

    let balance = (await instance.balanceOf(accounts[0])).toNumber();
    assert.equal(balance, 0, "Claimant got a token anyway")

    // ownerOf throws for nonexistent tokens, it doesn't say they're owned by nobody.
    // There's no way to poll existence either I don't think.
  })

  it("should allow revealing later", async function() {
    let instance = await MacroverseUniversalRegistry.deployed()

    // Remember our commitment from the last test?
    let to_claim = 0x1
    let nonce = 0xDEAD
    let commitment_id = 0

    console.log("Move time")

    // Advance time for 2 days which should be enough
    await advanceTime(60 * 24 * 2);

    console.log("Do reveal")

    // Wait for the reveal to try to happen
    await instance.reveal(commitment_id, to_claim, nonce)

    console.log("Check owner")

    // Get the owner of the token that shouldn't exist
    let token_owner = await instance.ownerOf(to_claim)

    // Make sure we own the token
    assert.equal(token_owner, accounts[0], "Token not owned by claimant");
  })
})
