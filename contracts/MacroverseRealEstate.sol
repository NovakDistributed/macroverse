pragma solidity ^0.6.10;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "openzeppelin-solidity/contracts/utils/Strings.sol";

/**
 * The MacroverseRealEstate contract keeps track of who currently owns virtual
 * real estate in the Macroverse world, at all scales. It supersedes the
 * MacroverseStarRegistry. Registration and Macroverse-specific manipulation of
 * tokens is accomplished through the MacroverseUniversalRegistry, which owns
 * this contract.
 *
 * The split between this contract and the MacroverseUniversalRegistry exists
 * to keep contract size under the limit. 
 */
contract MacroverseRealEstate is ERC721, Ownable {

    
    /**
     * Deploy the backend, taking mint, burn, and set-user commands from the deployer.
     */
    constructor() public ERC721("Macroverse Real Estate", "MRE") {
        // Set up new OpenZeppelin 3.0 automatic token URI system.
        // Good thing we match their format or we'd have to fork OZ.
        uint chainId = 0;
        assembly {
            chainId := chainid()
        }
        _setBaseURI(string(abi.encodePacked("https://api.macroverse.io/vre/v1/chain/", Strings.toString(chainId), "/token/")));
    }

    /**
     * Mint tokens at the direction of the owning contract.
     */
    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    /**
     * Burn tokens at the direction of the owning contract.
     */
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    /**
     * Publically expose a token existence test. Returns true if the given
     * token is owned by someone, and false otherwise. Note that tokens sent to
     * 0x0 but not burned may still exist.
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }
}

// SPDX-License-Identifier: UNLICENSED
