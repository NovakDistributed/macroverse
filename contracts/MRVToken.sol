pragma solidity ^0.4.11;


import "./zeppelin/token/StandardToken.sol";
import "./zeppelin/ownership/Ownable.sol";


/**
 * MRV token, distributed by crowdsale. Token and crowdsale functionality are unified in a single
 * contract, to make clear and restrict the conditions under which tokens can be created or destroyed.
 * Derived from OpenZeppelin CrowdsaleToken template.
 *
 * Key Crowdsale Facts:
 * 
 * * MRV tokens will be sold at a rate of 5,000 per ETH.
 *
 * * Unless adjusted later by the owner, up to 100 million tokens will be available.
 *
 * * An additional 5,000 tokens are reserved for the crowdsale beneficiary. 
 *
 * * Participate in the crowdsale by sending ETH to this contract, when the crowdsale is open.
 *
 * * Sending more ETH than required to purchase all the remaining tokens will fail.
 *
 * * Timers can be set to allow anyone to open/close the crowdsale at the proper time. The crowdsale
 *   operator reserves the right to set, unset, and reset these timers at any time, for any reason,
 *   and without notice.
 *
 * * The operator of the crowdsale has the ability to manually open it and close it, and reserves
 *   the right to do so at any time, for any reason, and without notice.
 *
 * * The crowdsale cannot be reopened, and no tokens can be created, after the crowdsale closes.
 *
 * * The crowdsale operator reserves the right to adjust the decimal places of the MRV token at
 *   any time after the crowdsale closes, for any reason, and without notice.
 *
 * * The crowdsale operator reserves the right to not open or close the crowdsale, not set the
 *   open or close timer, and generally refrain from doing things that the contract would otherwise
 *   authorize them to do.
 */
contract MRVToken is StandardToken, Ownable {

    // Token Parameters

    // From StandardToken we inherit balances and totalSupply.
    
    // What is the full name of the token?
    string public constant name = "Macroverse Token";
    // What is its suggested symbol?
    string public constant symbol = "MRV";
    // How many of the low base-10 digits are to the right of the decimal point?
    // Note that this is not constant! After the crowdsale, the contract owner can
    // adjust the decimal places, allowing for 10-to-1 splits and merges.
    uint8 public decimals;
    
    // Crowdsale Parameters
    
    // Where will funds collected during the crowdsale be sent?
    address beneficiary;
    // How many MRV can be sold in the crowdsale?
    uint public maxCrowdsaleSupplyInWholeTokens;
    // How many whole tokens are reserved for the beneficiary?
    uint public constant wholeTokensReserved = 5000;
    // How many tokens per ETH during the crowdsale?
    uint public constant wholeTokensPerEth = 5000;
    // Set to true when the crowdsale starts
    bool public crowdsaleStarted;
    // Set to true when the crowdsale ends
    bool public crowdsaleEnded;
    // We can also set some timers to open and close the crowdsale. 0 = timer is not set.
    // After this time, anyone can call startCrowdsaleByTimeout() and start the crowdsale.
    uint anyoneCanOpenCrowdsaleAfter = 0;
    // After this time, no contributions will be accepted, and anyone can call endCrowdsaleByTimeout() to end the crowdsale;
    uint acceptNoContributionsAfter = 0;
    
    ////////////
    // Constructor
    ////////////
    
    /**
    * Deploy a new MRVToken contract, paying crowdsale proceeds to the given address.
    */
    function MRVToken(address sendProceedsTo) {
        // Proceeds of the crowdsale go here.
        beneficiary = sendProceedsTo;
        
        // Start with 18 decimals, same as ETH
        decimals = 18;
        
        // Initially, the reserved tokens belong to the beneficiary.
        totalSupply = wholeTokensReserved * 10 ** 18;
        balances[beneficiary] = totalSupply;
        
        // Initially the crowdsale has not yet started or ended.
        crowdsaleStarted = false;
        crowdsaleEnded = false;
        // Default to a max supply of 100 million tokens available.
        maxCrowdsaleSupplyInWholeTokens = 100000000;
    }
    
    ////////////
    // Fallback function
    ////////////
    
    /**
    * This is the MAIN CROWDSALE ENTRY POINT. You participate in the crowdsale by 
    * sending ETH to this contract. That calls this function, which credits tokens
    * to the address or contract that sent the ETH.
    *
    * Since MRV tokens are sold at a rate of more than one per ether, and since
    * they, like ETH, have 18 decimal places (at the time of sale), any fractional
    * amount of ETH should be handled safely.
    *
    * Note that all orders are fill-or-kill. If you send in more ether than there are
    * tokens remaining to be bought, your transaction will be rolled back and you will
    * no tokens and waste your gas.
    */
    function() payable onlyDuringCrowdsale onlyBeforeCloseTimeout {
        createTokens(msg.sender);
    }
    
    ////////////
    // Modifiers (encoding important crowdsale logic)
    ////////////
    
    /**
     * Only allow some actions after the crowdsale is over.
     * This requires the crowdsale to be actually closed by a transaction, not just the timer to have elapsed.
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
     * Does not check whether the crowdsale is due to close; for that, use onlyBeforeCloseTimeout.
     */
    modifier onlyDuringCrowdsale {
        if (crowdsaleEnded) throw;
        if (!crowdsaleStarted) throw;
        _;
    }
    
    /**
     * Only allow some actions after the timer for when the crowdsale should open has elapsed.
     */
    modifier onlyAfterOpenTimeout {
        if (anyoneCanOpenCrowdsaleAfter == 0) throw;
        if (now <= anyoneCanOpenCrowdsaleAfter) throw;
        _;
    }
    
    /**
     * Only allow some actions before the timer for when to end the crowdsale expires, or when that timer has not been set.
     */
    modifier onlyBeforeCloseTimeout {
        if (acceptNoContributionsAfter != 0 && now > acceptNoContributionsAfter) throw;
        _;
    }
    
    /**
     * Only allow some actions after the timer for when the crowdsale should close has elapsed.
     */
    modifier onlyAfterCloseTimeout {
        if (acceptNoContributionsAfter == 0) throw;
        if (now <= acceptNoContributionsAfter) throw;
        _;
    }
    
    
    /**
     * Determine if the crowdsale is currently happening.
     */
    function isCrowdsaleActive() returns (bool) {
        return (crowdsaleStarted && !crowdsaleEnded);
    }
    
    
    ////////////
    // Before the crowdsale: configuration
    ////////////
    
    /**
     * Before the crowdsale opens, the max token count can be configured.
     */
    function setMaxSupply(uint newMaxInWholeTokens) onlyOwner onlyBeforeOpened {
        maxCrowdsaleSupplyInWholeTokens = newMaxInWholeTokens;
    }
    
    /**
     * Allow the owner to start the crowdsale.
     */
    function startCrowdsale() onlyOwner onlyBeforeOpened {
        crowdsaleStarted = true;
    }
    
    /**
     * Allow anyone to start the crowdsale if the time-until-start timer was set and has expired.
     */
    function startCrowdsaleByTimeout() onlyBeforeOpened onlyAfterOpenTimeout {
        crowdsaleStarted = true;
    }    
    
    /**
     * Let the owner start the timer for the crowdsale start. Without further owner intervention,
     * anyone will be able to open the crowdsale when the timer expires.
     * Further calls will re-set the timer to count from the time the transaction is processed.
     * The timer can be re-set after it has tripped, unless someone has already opened the crowdsale.
     */
    function setCrowdsaleOpenTimerFor(uint minutesFromNow) onlyOwner onlyBeforeOpened {
        anyoneCanOpenCrowdsaleAfter = now + minutesFromNow * 1 minutes;
    }
    
    /**
     * Let the owner stop the crowdsale open timer, as long as the crowdsale has not yet opened.
     */
    function clearCrowdsaleOpenTimer() onlyOwner onlyBeforeOpened {
        anyoneCanOpenCrowdsaleAfter = 0;
    }
    
    /**
     * Let the owner start the timer for the crowdsale end. Counts from when the function is called,
     * *not* from the start of the crowdsale.
     * Before the timer expires, it can be set to a different time, but after the timer expires, it
     * cannot be changed.
     */
    function setCrowdsaleCloseTimerFor(uint minutesFromNow) onlyOwner onlyBeforeCloseTimeout {
        acceptNoContributionsAfter = now + minutesFromNow * 1 minutes;
    }
    
    /**
     * Let the owner stop the crowdsale close timer, as long as it has not yet expired.
     */
    function clearCrowdsaleCloseTimer() onlyOwner onlyBeforeCloseTimeout {
        acceptNoContributionsAfter = 0;
    }
    
    ////////////
    // During the crowdsale
    ////////////
    
    /**
     * Create tokens for the given address, in response to a payment.
     * Cannot be called by outside callers; use the fallback function, which will create tokens for whoever pays it.
     */
    function createTokens(address recipient) internal onlyDuringCrowdsale onlyBeforeCloseTimeout {
        if (msg.value == 0) {
            throw;
        }

        uint tokens = msg.value.mul(wholeTokensPerEth); // Exploits the fact that we have 18 decimals, like ETH.
        
        var newTotalSupply = totalSupply.add(tokens);
        
        if (newTotalSupply > (wholeTokensReserved + maxCrowdsaleSupplyInWholeTokens) * 10 ** 18) {
            // This would be too many tokens issued.
            // Don't mess around with partial order fills.
            throw;
        }
        
        // Otherwise, we can fill the order entirely, so make the tokens and put them in the specified account.
        totalSupply = newTotalSupply;
        balances[recipient] = balances[recipient].add(tokens);

        // Lastly (after all state changes), send the money to the crowdsale beneficiary.
        // This allows the crowdsale contract itself not to hold any ETH.
        // It also means that ALL SALES ARE FINAL!
        if (!beneficiary.send(msg.value)) {
            throw;
        }
    }
    
    /**
     * Allow the owner to end the crowdsale.
     */
    function endCrowdsale() onlyOwner onlyDuringCrowdsale {
        crowdsaleEnded = true;
    }
    
    /**
     * Allow anyone to end the crowdsale if the time-until-end timer was set and has expired.
     */
    function endCrowdsaleByTimeout() onlyDuringCrowdsale onlyAfterCloseTimeout {
        crowdsaleEnded = true;
    }    
    
    ////////////
    // After the crowdsale: token maintainance
    ////////////
    
    /**
     * When the crowdsale is finished, the contract owner may adjust the decimal places for display purposes.
     * This should work like a 10-to-1 split or reverse-split.
     * The point of this mechanism is to keep the individual MRV tokens from getting inconveniently valuable or cheap.
     * However, it relies on the contract owner taking the time to update the decimal place value.
     * Note that this changes the decimals IMMEDIATELY with NO NOTICE to users.
     */
    function setDecimals(uint8 newDecimals) onlyOwner onlyAfterClosed {
        decimals = newDecimals;
    }

}