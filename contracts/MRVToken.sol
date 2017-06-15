pragma solidity ^0.4.11;


import "./zeppelin/token/StandardToken.sol";


/**
 * MRV token, distributed by crowdsale.
 * Derived from OpenZeppelin CrowdsaleToken template.
 */
contract MRVToken is StandardToken {

    string public constant name = "Macroverse Token";
    string public constant symbol = "MRV";
    uint public constant decimals = 18;
    address public multisig;

    /**
    * Deploy a new MRVToken contract, paying to the given multisig wallet.
    */
    function MRVToken(address _multisig) {
        multisig = _multisig;
    }


    // 1 ether = 5000 MRV
    uint public constant PRICE = 5000;

    /**
    * @dev Fallback function which receives ether and sends the appropriate number of tokens to the 
    * msg.sender.
    */
    function () payable {
        createTokens(msg.sender);
    }

    /**
    * @dev Creates tokens and send to the specified address.
    * @param recipient The address which will recieve the new tokens.
    */
    function createTokens(address recipient) payable {
        if (msg.value == 0) {
            throw;
        }

        uint tokens = msg.value.mul(getPrice());
        totalSupply = totalSupply.add(tokens);

        balances[recipient] = balances[recipient].add(tokens);

        if (!multisig.send(msg.value)) {
            throw;
        }
    }

    /**
    * @dev replace this with any other price function
    * @return The price per unit of token. 
    */
    function getPrice() constant returns (uint result) {
        return PRICE;
    }
}