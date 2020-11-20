let MacroverseRealEstate = artifacts.require("MacroverseRealEstate")
let MacroverseUniversalRegistry = artifacts.require("MacroverseUniversalRegistry")
let MRVToken = artifacts.require("MRVToken")

// Load the Macroverse module JavaScript
let mv = require('../src')

const BN = require('bn.js')
const Web3Utils = require('web3-utils')

async function assert_throws(promise, message) {
  try {
    await promise
    assert.ok(false, message)
  } catch {
    // OK
  }
}

async function getChainID() {
  var net = undefined;
  if (typeof web3.eth.getChainId !== 'undefined') {
    // We actually have the API that lets us query this
    net = web3.eth.getChainId()
  } else if (typeof web3.version.getNetwork !== 'undefined') {
    // We have getNetwork, so guess based on that.
    // In many cases the chain ID and the network are the same.
    net = web3.version.getNetwork()
  } else if (typeof web3.eth.net.getNetworkType !== 'undefined') {
    // Try and go form string to network ID
    let nettype = await web3.eth.net.getNetworkType()
    console.log('Network type: ', nettype)
    switch(nettype) {
      case 'main':
        net = 1
        break
      case 'rinkeby':
        net = 4
        break
      case 'private':
        // Truffle test claims to be chain 1...
        // TODO: What does ganache say/look like?
        net = 1
        break
      default:
        net = 12345
        break
    }
  } else {
    throw new Error('No way to inspect network')
  }
  
  if (net == 1337 || net.toString(10) == '1337') {
    // This Truffle test network really looks like 1 to the on-chain code.
    net = 1
  }
  return net
}

contract('MacroverseRealEstate', function(accounts) {
  it("should report the correct URL for a token that exists", async function() {
    let instance = await MacroverseRealEstate.deployed()
    let reg = await MacroverseUniversalRegistry.deployed()
    let mrv = await MRVToken.deployed()
    
    let chainId = (await getChainID()).toString(10)
    let keypath = '0.0.0.33.2'
    let tokenNumber = mv.keypathToToken(keypath).toString(10)
    
    // With OpenZeppelin 3.0 we need the token to actually exist before we can get its URI.
    assert.equal((await mrv.balanceOf.call(accounts[0])), Web3Utils.toWei("5000", "ether"), "We start with the expected amount of MRV for the test")
    await mrv.approve(reg.address, await mrv.balanceOf.call(accounts[0]))
    let nonce = mv.generateNonce()
    let data_hash = mv.hashTokenAndNonce(tokenNumber, nonce)
    await reg.commit(data_hash, Web3Utils.toWei("1000", "ether"), {from: accounts[0]})
    await mv.advanceTime(10)
    await reg.reveal(tokenNumber, nonce)

    let url = await instance.tokenURI.call(tokenNumber)
    assert.equal(url, 'https://api.macroverse.io/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")
    
  })
  
  it("should prohibit non-owners changing token URI domain", async function() {
    let instance = await MacroverseRealEstate.deployed()
    
    let chainId = (await getChainID()).toString(10)
    let keypath = '0.0.0.33.2'
    let tokenNumber = mv.keypathToToken(keypath).toString(10)
    
    await assert_throws(instance.setTokenMetadataDomain('google.biz'), "Changed token domain")
    
    let url = await instance.tokenURI.call(tokenNumber)
    assert.equal(url, 'https://api.macroverse.io/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")
  })
  
  it("should prohibit non-owners changing token URI domain via the MacroverseUniversalRegistry", async function() {
    let instance = await MacroverseRealEstate.deployed()
    let reg = await MacroverseUniversalRegistry.deployed()
    
    let chainId = (await getChainID()).toString(10)
    let keypath = '0.0.0.33.2'
    let tokenNumber = mv.keypathToToken(keypath).toString(10)
    
    await assert_throws(reg.setTokenMetadataDomain('google.biz', {from: accounts[1]}), "Changed token domain")
    
    let url = await instance.tokenURI.call(tokenNumber)
    assert.equal(url, 'https://api.macroverse.io/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")
  })
  
  it("should allow owners changing token URI domain via the MacroverseUniversalRegistry", async function() {
    let instance = await MacroverseRealEstate.deployed()
    let reg = await MacroverseUniversalRegistry.deployed()
    
    let chainId = (await getChainID()).toString(10)
    let keypath = '0.0.0.33.2'
    let tokenNumber = mv.keypathToToken(keypath).toString(10)
    
    await reg.setTokenMetadataDomain('google.biz')
    
    let url = await instance.tokenURI.call(tokenNumber)
    assert.equal(url, 'https://google.biz/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")
    
    // Make sure to change it back
    await reg.setTokenMetadataDomain('api.macroverse.io')
    
    let url2 = await instance.tokenURI.call(tokenNumber)
    assert.equal(url2, 'https://api.macroverse.io/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")
    
    // Release token we've been holding for all the tests.
    await reg.release(tokenNumber)
  })
})
