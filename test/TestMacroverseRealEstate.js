let MacroverseRealEstate = artifacts.require("MacroverseRealEstate")

// Load the Macroverse module JavaScript
let mv = require('../src')

const BN = require('bn.js')
const Web3Utils = require('web3-utils')

async function getChainID() {
  if (typeof web3.eth.getChainId !== 'undefined') {
    // We actually have the API that lets us query this
    return web3.eth.getChainId()
  }
  if (typeof web3.version.getNetwork !== 'undefined') {
    // We have getNetwork, so guess based on that.
    // In many cases the chain ID and the network are the same.
    return web3.version.getNetwork()
  }
  if (typeof web3.eth.net.getNetworkType !== 'undefined') {
    // Try and go form string to network ID
    let nettype = await web3.eth.net.getNetworkType()
    console.log('Network type: ', nettype)
    switch(nettype) {
      case 'main':
        return 1
      case 'rinkeby':
        return 4
      case 'private':
        // Truffle test claims to be chain 1...
        // TODO: What does ganache say/look like?
        return 1
      default:
        return 12345
    }
  }
  throw new Error('No way to inspect network')
}

contract('MacroverseRealEstate', function(accounts) {
  it("should report the correct URL for a token, even if the token doesn't exist", async function() {
    let instance = await MacroverseRealEstate.deployed()
    
    let chainId = (await getChainID()).toString(10)

    let keypath = '0.0.0.33.2'
    let tokenNumber = mv.keypathToToken(keypath).toString(10)

    let url = await instance.tokenURI.call(tokenNumber)

    assert.equal(url, 'https://api.macroverse.io/vre/v1/chain/' + chainId + '/token/' + tokenNumber, "We got the expected URL")

  })
})
