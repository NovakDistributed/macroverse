pragma solidity ^0.6.10;

import "./MRVToken.sol";

/**
 * MRVToken contract which adds unrestricted minting by anyone.
 *
 * Only useful on a testnet.
 */
contract TestnetMRVToken is MRVToken {

    /**
     * Make a new TestnetMRVToken.
     * Passes through arguments to the base MRVToken constructor.
     */
    constructor(address payable sendProceedsTo, address sendTokensTo) MRVToken(sendProceedsTo, sendTokensTo) public {
        // Send the event we forget to send in the base implementation.
        Transfer(address(0), sendTokensTo, totalSupply);
    }

   
    /**
     * Allow anyone to mint themselves any amount of tokens, for testing.
     * Unless it's truly huge and going to DoS the contract by pegging total supply.
     */
    function mint(uint256 amount) public {
        if (amount > 0x0000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
            revert();
        }
        totalSupply = totalSupply.add(amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        Transfer(address(0), msg.sender, amount);
    }

}

// SPDX-License-Identifier: UNLICENSED
