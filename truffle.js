// We have a rinkeby-infura network, for which we try and find some secret Infura credentials in .env
// We don't use the Infura "secret" (passed as basic auth user), just the ID (which we keep secret)
// You can get your own from Infura by signing up with them, or use a different node to deploy
require('dotenv').config()

// We want to be able to deploy from keys in keystore files
const KeystoreProvider = require('truffle-keystore-provider')

// We need memoization or we will be prompted for a password every time.
// See https://github.com/yondonfu/truffle-keystore-provider
const memoizeKeystoreProviderCreator = () => {
    let providers = {}

    // KEYSTORE_DIR must have a ./keystore under it.
    // KEYSTORE_NAME is a file under that keystore directory and must be lowercase (supposed to be an address)

    return (network, account, dataDir, providerUrl) => {
        let key = JSON.stringify([dataDir, account, providerUrl])
        console.log('Get provider ' + network + ' with key: ' + key)
        if (key in providers) {
            return providers[key]
        } else {
            const provider = new KeystoreProvider(account, dataDir, providerUrl)
            providers[key] = provider
            return provider
        }
    }
}

const createKeystoreProvider = memoizeKeystoreProviderCreator()



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
       gasPrice: 4000000000,
       timeoutBlocks: 1000
    },
    live: {
      network_id: 1,
      host: "localhost",
      port: 8546,   // Different than the default
      from: "0x368651F6c2b3a7174ac30A5A062b65F2342Fb6F1",
      gas: 8000000, // Knock down because it has to be less than block gas limit
      gasPrice: 100000000000, // 100 Gwei
      timeoutBlocks: 1000
    },
    live_local: {
      network_id: 1,
      host: "localhost", // Ignored
      provider: () => {  return createKeystoreProvider('live_local', env['LIVE_KEYSTORE_NAME'], env['KEYSTORE_DIR'], 'http://localhost:8545/') },
      gas: 8000000, // Knock down because it has to be less than block gas limit
      gasPrice: 100000000000,
      timeoutBlocks: 1000
    },
    rinkeby_local: {
      network_id: 4,
      host: "localhost", // Ignored
      provider: () => { return createKeystoreProvider('rinkeby_local', env['RINKEBY_KEYSTORE_NAME'], env['KEYSTORE_DIR'], 'http://localhost:8546/') },
      gas: 8000000, // Knock down because it has to be less than block gas limit
      gasPrice: 4000000000,
      timeoutBlocks: 1000
    },
    rinkeby_infura: {
      network_id: 4,
      host: "localhost", // Ignored
      provider: () => { return createKeystoreProvider('rinkeby_infura', env['RINKEBY_KEYSTORE_NAME'], env['KEYSTORE_DIR'], 'https://rinkeby.infura.io/v3/' + env['INFURA_PROJECT']) },
      gas: 8000000, // Knock down because it has to be less than block gas limit
      gasPrice: 4000000000,
      timeoutBlocks: 1000
    },
    live_infura: {
      network_id: 1,
      host: "localhost", // Ignored
      provider: () => { return createKeystoreProvider('rinkeby_infura', env['LIVE_KEYSTORE_NAME'], env['KEYSTORE_DIR'], 'https://mainnet.infura.io/v3/' + env['INFURA_PROJECT']) },
      gas: 8000000, // Knock down because it has to be less than block gas limit
      gasPrice: 100000000000,
      timeoutBlocks: 1000
    },
    ganacheFork: {
      network_id: 1,
      host: "127.0.0.1",
      port: 8549
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : {
      currency: 'USD'
    }
  },
  plugins: ['truffle-plugin-verify'],
  verify: {
    preamble: "SPDX-License-Identifier: UNLICENSED\nSee https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2a0f2a8ba807b41360e7e092c3d5bb1bfbeb8b50/LICENSE and https://github.com/NovakDistributed/macroverse/blob/eea161aff5dba9d21204681a3b0f5dbe1347e54b/LICENSE"
  },
  api_keys: {
    // Verification is "Powered by Etherscan.io APIs"
    etherscan: env['ETHERSCAN_API_KEY']
  },
  compilers: {
    solc: {
      version: '0.6.10',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
