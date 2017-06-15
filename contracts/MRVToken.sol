pragma solidity ^0.4.11;


import "./zeppelin/token/StandardToken.sol";
import "./zeppelin/ownership/Ownable.sol";


/**
 * MRV token, distributed by crowdsale.
 * Derived from OpenZeppelin CrowdsaleToken template.
 */
contract MRVToken is StandardToken, Ownable {

    string public constant name = "Macroverse Token";
    string public constant symbol = "MRV";
    uint public decimals;
    address public multisig;
    
    // How many MRV can be sold in the crowdsale?
    uint public maxSupply;
    
    bool crowdsaleStarted;
    bool crowdsaleEnded;

    /**
    * Deploy a new MRVToken contract, paying to the given multisig wallet.
    */
    function MRVToken(address _multisig) {
        multisig = _multisig;
        decimals = 18; // Start with 18 decimals, same as ETH
        crowdsaleStarted = false;
        crowdsaleEnded = false;
        // Default to a max supply of 100 million tokens available.
        maxSupply = 100000000;
    }
    
    /**
     * Only allow some actions after the crowdsale is over.
     */
    modifier onlyAfterClosed {
        if (!crowdsaleEnded) throw;
        _;
    }
    
    /**
     * Only allow some actions before the crowdsale starts.
     */
    modifier onlyBeforeOpened {
        if (crowdsaleStarted) throw;
        _;
    }
    
    /**
     * Only allow some actions while the crowdsale is active.
     */
    modifier onlyDuringCrowdsale {
        if (crowdsaleEnded) throw;
        if (!crowdsaleStarted) throw;
        _;
    }
    
    /**
     * Determine if the crowdsale is currently happening.
     */
    function isCrowdsaleActive() returns (bool) {
        return (crowdsaleStarted && !crowdsaleEnded);
    }
    
    /**
     * Start the crowdsale.
     */
    function startCrowdsale() onlyOwner onlyBeforeOpened {
        crowdsaleStarted = true;
    }
    
    /**
     * End the crowdsale.
     */
    function endCrowdsale() onlyOwner onlyDuringCrowdsale {
        crowdsaleEnded = true;
    }
    
    /**
     * When the crowdsale is finished, the contract owner can adjust the decimal places for display purposes.
     */
    function setDecimals(uint new_decimals) onlyOwner onlyAfterClosed {
        decimals = new_decimals;
    }
    
    /**
     * Before the crowdsale opens, the max token count can be configured.
     */
    function setMaxSupply(uint new_max) onlyOwner onlyBeforeOpened {
        maxSupply = new_max;
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
    function createTokens(address recipient) payable onlyDuringCrowdsale {
        if (msg.value == 0) {
            throw;
        }

        uint tokens = msg.value.mul(getPrice()); // Exploits the fact that we have 18 decimals, like ETH.
        
        var newTotalSupply = totalSupply.add(tokens);
        
        if (newTotalSupply > maxSupply * 10 ** 18) {
            // This would be too many tokens issued.
            // Don't mess around with partial order fills.
            throw;
        }
        
        totalSupply = newTotalSupply;

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