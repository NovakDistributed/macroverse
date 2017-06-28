module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id. We could use "default" but then Solidity tests can't find libraries.
    },
    live: {
      network_id: 1,
      host: "localhost",
      port: 8546,   // Different than the default
      from: "0x368651F6c2b3a7174ac30A5A062b65F2342Fb6F1",
      gas: 4700000, // Knock down because it has to be les than block gas limit
      gasPrice: 49000000000 // Defaults to 100 gwei = 100 shannon = 100 billion, which is extremely high.
    }
  }
};
