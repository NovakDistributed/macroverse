pragma solidity ^0.5.2;


import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HasNoTokens.sol";
import "./HasNoContracts.sol";


/**
 * MRV token, distributed by crowdsale. Token and crowdsale functionality are unified in a single
 * contract, to make clear and restrict the conditions under which tokens can be created or destroyed.
 * Derived from OpenZeppelin CrowdsaleToken template.
 *
 * Key Crowdsale Facts:
 * 
 * * MRV tokens will be sold at a rate of 5,000 per ETH.
 *
 * * All MRV token sales are final. No refunds can be issued by the contract.
 *
 * * Unless adjusted later by the crowdsale operator, up to 100 million tokens will be available.
 *
 * * An additional 5,000 tokens are reserved. 
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
 *   any time after the crowdsale closes, for any reason, and without notice. MRV tokens are
 *   initially divisible to 18 decimal places.
 *
 * * The crowdsale operator reserves the right to not open or close the crowdsale, not set the
 *   open or close timer, and generally refrain from doing things that the contract would otherwise
 *   authorize them to do.
 *
 * * The crowdsale operator reserves the right to claim and keep any ETH or tokens that end up in
 *   the contract's account. During normal crowdsale operation, ETH is not stored in the contract's
 *   account, and is instead sent directly to the beneficiary.
 */
contract MRVToken is ERC20, Ownable, HasNoTokens, HasNoContracts {

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
    address payable beneficiary;
    // How many MRV can be sold in the crowdsale?
    uint public maxCrowdsaleSupplyInWholeTokens;
    // How many whole tokens are reserved for the beneficiary?
    uint public constant wholeTokensReserved = 5000;
    // How many tokens per ETH during the crowdsale?
    uint public constant wholeTokensPerEth = 5000;
    
    // Set to true when the crowdsale starts
    // Internal flag. Use isCrowdsaleActive instead().
    bool crowdsaleStarted;
    // Set to true when the crowdsale ends
    // Internal flag. Use isCrowdsaleActive instead().
    bool crowdsaleEnded;
    // We can also set some timers to open and close the crowdsale. 0 = timer is not set.
    // After this time, the crowdsale will open with a call to checkOpenTimer().
    uint public openTimer = 0;
    // After this time, no contributions will be accepted, and the crowdsale will close with a call to checkCloseTimer().
    uint public closeTimer = 0;
    
    ////////////
    // Constructor
    ////////////
    
    /**
    * Deploy a new MRVToken contract, paying crowdsale proceeds to the given address,
    * and awarding reserved tokens to the other given address.
    */
    constructor(address payable sendProceedsTo, address sendTokensTo) public {
        // Proceeds of the crowdsale go here.
        beneficiary = sendProceedsTo;
        
        // Start with 18 decimals, same as ETH
        decimals = 18;
        
        // Initially, the reserved tokens belong to the given address.
        // TODO: This change for OZ 2.0 compatibility causes the code to differ from the behavior of the mainnet deployed contract!
        _mint(sendTokensTo, wholeTokensReserved * 10 ** 18);
        
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
    * get no tokens and waste your gas.
    */
    function() external payable onlyDuringCrowdsale {
        createTokens(msg.sender);
    }
    
    ////////////
    // Events
    ////////////
    
    // Fired when the crowdsale is recorded as started.
    event CrowdsaleOpen(uint time);
    // Fired when someone contributes to the crowdsale and buys MRV
    event TokenPurchase(uint time, uint etherAmount, address from);
    // Fired when the crowdsale is recorded as ended.
    event CrowdsaleClose(uint time);
    // Fired when the decimal point moves
    event DecimalChange(uint8 newDecimals);
    
    ////////////
    // Modifiers (encoding important crowdsale logic)
    ////////////
    
    /**
     * Only allow some actions before the crowdsale closes, whether it's open or not.
     */
    modifier onlyBeforeClosed {
        checkCloseTimer();
        if (crowdsaleEnded) revert();
        _;
    }
    
    /**
     * Only allow some actions after the crowdsale is over.
     * Will set the crowdsale closed if it should be.
     */
    modifier onlyAfterClosed {
        checkCloseTimer();
        if (!crowdsaleEnded) revert();
        _;
    }
    
    /**
     * Only allow some actions before the crowdsale starts.
     */
    modifier onlyBeforeOpened {
        checkOpenTimer();
        if (crowdsaleStarted) revert();
        _;
    }
    
    /**
     * Only allow some actions while the crowdsale is active.
     * Will set the crowdsale open if it should be.
     */
    modifier onlyDuringCrowdsale {
        checkOpenTimer();
        checkCloseTimer();
        if (crowdsaleEnded) revert();
        if (!crowdsaleStarted) revert();
        _;
    }

    ////////////
    // Status and utility functions
    ////////////
    
    /**
     * Determine if the crowdsale should open by timer.
     */
    function openTimerElapsed() public view returns (bool) {
        return (openTimer != 0 && now > openTimer);
    }
    
    /**
     * Determine if the crowdsale should close by timer.
     */
    function closeTimerElapsed() public view returns (bool) {
        return (closeTimer != 0 && now > closeTimer);
    }
    
    /**
     * If the open timer has elapsed, start the crowdsale.
     * Can be called by people, but also gets called when people try to contribute.
     */
    function checkOpenTimer() public {
        if (openTimerElapsed()) {
            crowdsaleStarted = true;
            openTimer = 0;
            emit CrowdsaleOpen(now);
        }
    }
    
    /**
     * If the close timer has elapsed, stop the crowdsale.
     */
    function checkCloseTimer() public {
        if (closeTimerElapsed()) {
            crowdsaleEnded = true;
            closeTimer = 0;
            emit CrowdsaleClose(now);
        }
    }
    
    /**
     * Determine if the crowdsale is currently happening.
     */
    function isCrowdsaleActive() public view returns (bool) {
        // The crowdsale is happening if it is open or due to open, and it isn't closed or due to close.
        return ((crowdsaleStarted || openTimerElapsed()) && !(crowdsaleEnded || closeTimerElapsed()));
    }
    
    ////////////
    // Before the crowdsale: configuration
    ////////////
    
    /**
     * Before the crowdsale opens, the max token count can be configured.
     */
    function setMaxSupply(uint newMaxInWholeTokens) public onlyOwner onlyBeforeOpened {
        maxCrowdsaleSupplyInWholeTokens = newMaxInWholeTokens;
    }
    
    /**
     * Allow the owner to start the crowdsale manually.
     */
    function openCrowdsale() public onlyOwner onlyBeforeOpened {
        crowdsaleStarted = true;
        openTimer = 0;
        emit CrowdsaleOpen(now);
    }
    
    /**
     * Let the owner start the timer for the crowdsale start. Without further owner intervention,
     * anyone will be able to open the crowdsale when the timer expires.
     * Further calls will re-set the timer to count from the time the transaction is processed.
     * The timer can be re-set after it has tripped, unless someone has already opened the crowdsale.
     */
    function setCrowdsaleOpenTimerFor(uint minutesFromNow) public onlyOwner onlyBeforeOpened {
        openTimer = now + minutesFromNow * 1 minutes;
    }
    
    /**
     * Let the owner stop the crowdsale open timer, as long as the crowdsale has not yet opened.
     */
    function clearCrowdsaleOpenTimer() public onlyOwner onlyBeforeOpened {
        openTimer = 0;
    }
    
    /**
     * Let the owner start the timer for the crowdsale end. Counts from when the function is called,
     * *not* from the start of the crowdsale.
     * It is possible, but a bad idea, to set this before the open timer.
     */
    function setCrowdsaleCloseTimerFor(uint minutesFromNow) public onlyOwner onlyBeforeClosed {
        closeTimer = now + minutesFromNow * 1 minutes;
    }
    
    /**
     * Let the owner stop the crowdsale close timer, as long as it has not yet expired.
     */
    function clearCrowdsaleCloseTimer() public onlyOwner onlyBeforeClosed {
        closeTimer = 0;
    }
    
    
    ////////////
    // During the crowdsale
    ////////////
    
    /**
     * Create tokens for the given address, in response to a payment.
     * Cannot be called by outside callers; use the fallback function, which will create tokens for whoever pays it.
     */
    function createTokens(address recipient) internal onlyDuringCrowdsale {
        if (msg.value == 0) {
            revert();
        }

        uint tokens = msg.value.mul(wholeTokensPerEth); // Exploits the fact that we have 18 decimals, like ETH.
        
        uint256 newTotalSupply = totalSupply().add(tokens);
        
        if (newTotalSupply > (wholeTokensReserved + maxCrowdsaleSupplyInWholeTokens) * 10 ** 18) {
            // This would be too many tokens issued.
            // Don't mess around with partial order fills.
            revert();
        }
        
        // Otherwise, we can fill the order entirely, so make the tokens and put them in the specified account.
        // TODO: This has been updated for OZ 2.0; the deployed contract on chain does NOT use the OZ minting logic.
        // In particular, it did not emit transfer events for minted tokens, which confuses some blockchain viewers.
        _mint(recipient, tokens);
        
        // Announce the purchase
        emit TokenPurchase(now, msg.value, recipient);

        // Lastly (after all state changes), send the money to the crowdsale beneficiary.
        // This allows the crowdsale contract itself not to hold any ETH.
        // It also means that ALL SALES ARE FINAL!
        if (!beneficiary.send(msg.value)) {
            revert();
        }
    }
    
    /**
     * Allow the owner to end the crowdsale manually.
     */
    function closeCrowdsale() public onlyOwner onlyDuringCrowdsale {
        crowdsaleEnded = true;
        closeTimer = 0;
        emit CrowdsaleClose(now);
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
    function setDecimals(uint8 newDecimals) public onlyOwner onlyAfterClosed {
        decimals = newDecimals;
        // Announce the change
        emit DecimalChange(decimals);
    }
    
    /**
     * If Ether somehow manages to get into this contract, provide a way to get it out again.
     * During normal crowdsale operation, ETH is immediately forwarded to the beneficiary.
     */
    function reclaimEther() external onlyOwner {
        // Send the ETH. Make sure it worked.
        // Go through uint160 to make owner payable
        assert(address(uint160(owner())).send(address(this).balance));
    }

    // TODO: the following two functions do NOT exist in the on-chain mainnet
    // version of the contract. They are here to allow the project to build
    // with newer versions of OpenZeppelin.

    /**
     * Block the increaseAllowance method which is not in the mainned deployed
     * contract, but which OZ added to their library after we deployed.
     */
    function increaseAllowance(address /* spender */, uint256 /* addedValue */) public returns (bool) {
        revert();
    }

    /**
     * Block the decreaseAllowance method which is not in the mainned deployed
     * contract, but which OZ added to their library after we deployed.
     */
    function decreaseAllowance(address /* spender */, uint256 /* addedValue */) public returns (bool) {
        revert();
    }

}
