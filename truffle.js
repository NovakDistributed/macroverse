module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "default" // Match any network id except those otherwise specified
    },
    live: {
      network_id: 1,
      host: "localhost",
      port: 8546,   // Different than the default
      from: "0x368651F6c2b3a7174ac30A5A062b65F2342Fb6F1"
    }
  }
};
