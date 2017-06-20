pragma solidity ^0.4.11;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

/**
 * The Macroverse Registry keeps track of who currently owns virtual real estate in the Macroverse world.
 */
contract MacroverseRegistry is ControlledAccess {
    
    // This maps from star or other body seed to the address that owns it.
    mapping(bytes32 => address) ownerOf;
    
    /**
     * Stores the information needed to find a planet/star/moon/whatever.
     */
    struct EntityLocation {
        // What sector is it in?
        int16 sectorX;
        int16 sectorY;
        int16 sectorZ;
        // What object (i.e. star) in that sector does it belong to?
        uint16 objectNumber;
        // What body (i.e. planet) orbiting the star does it belong to?
        // 0xFFFF = the star itself.
        uint16 bodyNumber;
        // What satellite (i.e. moon) orbiting the planet does it belong to?
        // 0xFFFF = the planet itself.
        uint16 satelliteNumber;
    }
    
    // This stores the locations of things.
    mapping(bytes32 => EntityLocation) locationOf;
    
    /**
     * Deploy a new copy of the Macroverse registry. Allows objects to be owned.
     */
    function MacroverseRegistry(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) {
        
    }
    
    
    
    
}