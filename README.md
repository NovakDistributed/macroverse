# Macroverse
## An entire universe on the Ethereum blockchain

[Official Site](https://macroverse.io/)

Macroverse is a project to deploy a procedurally-generated universe to the Ethereum blockchain, suitable for use as a setting for games and a subject for exploration.

Players will be able to own a token, MRV, that provides access to this procedural world. Players will also be able to claim and trade pieces of virtual real estate, with in-game benefits in supported games.

For full details, see the [whitepaper](https://macroverse.io/MacroverseWhitepaper.pdf) and read the [smart contracts](https://github.com/NovakDistributed/macroverse/tree/master/contracts).

Macroverse is a project of Novak Distributed. Macroverse is (C) 2017 Novak Distributed, all rights reserved.

## Installation

Make sure you have the Truffle build tool:

```
npm install -g truffle
```

And testrpc:
```
npm install -g ethereum-testrpc
```

Then install from source:

```
git clone https://github.com/NovakDistributed/macroverse.git
cd macroverse
npm install
```

Then build the smart contracts (to make sure they still work):

```
truffle build
```

Start a trestrpc node:

```
testrpc
```

And run the tests:

```
truffle test
```




