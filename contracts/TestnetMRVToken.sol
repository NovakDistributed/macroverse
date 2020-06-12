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
        // Nothing to do!
    }

   
    /**
     * Allow anyone to mint themselves any amount of tokens, for testing.
     */
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

}

// SPDX-License-Identifier: UNLICENSED
