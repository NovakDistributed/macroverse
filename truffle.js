// We have a rinkeby-infura network, for which we try and find some secret Infura credentials in .env
// We don't use the Infura "secret" (passed as basic auth user), just the ID (which we keep secret)
// You can get your own from Infura by signing up with them, or use a different node to deploy
require('dotenv').config()

// We want to be able to deploy from keys in keystore files
const KeystoreProvider = require('truffle-keystore-provider')

// We need memoization or we will be prompted for a password every time.
// See https://github.com/yondonfu/truffle-keystore-provider
let providers = {}
function makeKeystoreProvider(account, dataDir, providerUrl) {
  if (providerUrl in providers) {
    return providers[providerUrl]
  } else {
    const provider = new KeystoreProvider(account, dataDir, providerUrl)
    providers[providerUrl] = provider
    return provider
  }
}



// We need to get env vars somewhere where our provider getter can see them
const env = process.env

module.exports = {
  networks: {
    // Development network is now all in-memory in Truffle 4.
    truffle: {
       host: "localhost",
       port: 9545,
       network_id: "4447",
       gas: 8000000,
       gasPrice: 4000000000
    },
    live: {
      network_id: 1,
      host: "localhost",
      port: 8546,   // Different than the default
      from: "0x368651F6c2b3a7174ac30A5A062b65F2342Fb6F1",
      gas: 8000000, // Knock down because it has to be les than block gas limit
      gasPrice: 4000000000 // Defaults to 100 gwei = 100 shannon = 100 billion, which is extremely high.
    },
    rinkeby_infura: {
      network_id: 4,
      host: "localhost", // Ignored
      provider: function() {
        // KEYSTORE_DIR must have a ./keystore under it.
        // KEYSTORE_NAME is a file under that keystore directory
        return makeKeystoreProvider(env['KEYSTORE_NAME'], env['KEYSTORE_DIR'], 'https://rinkeby.infura.io/v3/' + env['INFURA_PROJECT'])
      },
      gas: 8000000, // Knock down because it has to be les than block gas limit
      gasPrice: 4000000000 // Defaults to 100 gwei = 100 shannon = 100 billion, which is extremely high.
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : {
      currency: 'USD'
    }
  },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    // Verification is "Powered by Etherscan.io APIs"
    etherscan: env['ETHERSCAN_API_KEY']
  },
  compilers: {
    solc: {
      version: '0.5.14'
    }
  }
};
