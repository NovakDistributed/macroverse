// index.js: Main file for the Macroverse JavaScript library

// The code in this file helps you interact with the Macroverse contracts by
// defining JS equivalents or counterparts to some of the on-chain Solidity
// code.

const BigNumber = require('bignumber.js')

// We need this for the Solidity-alike hashing functions
const Web3Utils = require('web3-utils')

var mv = module.exports

mv.REAL_FBITS = 40
mv.REAL_ONE = (new BigNumber(2)).pow(mv.REAL_FBITS)

mv.fromReal = function(real) {
  // Convert from 40 bit fixed point
  return real.dividedBy(mv.REAL_ONE).toNumber()
}

mv.toReal = function(float) {
  // Convert to 40 bit fixed point, with 88 integral bits, one of which is sign.
  
  if (isNaN(float)) {
    throw new Error("NaN cannot be represented in fixed-point!")
  }
  
  if (Math.log2(Math.abs(float)) >= 87) {
    throw new Error("Magnitude of " + float + " is too large for 88 bit signed int!")
  }
  
  // Make sure to convert to a string because the bignumber library gets upset
  // when you use more than 15 digits and are an actual number. See
  // <https://github.com/MikeMcl/bignumber.js/issues/11>
  return mv.REAL_ONE.times(float.toString())
}

// Convert from float radians to float degrees.
mv.degrees = require('radians-degrees')
// And back again
mv.radians = require('degrees-radians')

// Useful astronomical constants
// 1 Astronomical Unit in meters
mv.AU = 149597870700
// The official Lunar Distance in meters
mv.LD = 384402000
// G in per-solar-mass units, as used in Macroverse orbital mechanics.
// This value of G is very precise, but the uncertainty comes in converting solar mass units to kilograms
mv.G_PER_SOL = 132712875029098577920 // m^3 s^-2 sols^-1
// How many earth masses in a solar mass?
mv.EARTH_MASSES_PER_SOLAR_MASS = 332950
// How many lunar masses are in an Earth mass?
mv.LUNAR_MASSES_PER_EARTH_MASS = 81.3
// How heavy is the Earth, for display purposes, in kg?
mv.EARTH_MASS = 5.9721986E24
// The luminosity of the sun, in watts
mv.SOLAR_LUMINOSITY = 3.828E26

// A Julian year is exactly 365.25 days and is our basic time unit.
// We think about orbits in terms of radians per Julian year.
mv.JULIAN_YEAR = 365.25 * 24 * 60 * 60
// A siderial year is about 365.25636 seconds and is Earth's orbital period
mv.SIDERIAL_YEAR = 365.25636 * 24 * 60 * 60
// A day is a day (24 hours of 60 minutes of 60 seconds)
mv.DAY = 24 * 60 * 60

// When did the Macroverse world start, in Unix time?
// Subtract from block timestamp to get seconds since epoch for block.
mv.EPOCH = 1518671883

// Convert a Unix-time block timestamp to Julian years since Macroverse epoch
mv.yearsSinceEpoch = function(unixTime) {
  return (unixTime - mv.EPOCH) / mv.JULIAN_YEAR
}

mv.objectClasses = ['Supergiant', 'Giant', 'MainSequence', 'WhiteDwarf', 'NeutronStar', 'BlackHole']
mv.objectClass = {}
for (let i = 0; i < mv.objectClasses.length; i++) {
  // Make the map from name to index
  mv.objectClass[mv.objectClasses[i]] = i
}

mv.spectralTypes = ['TypeO', 'TypeB', 'TypeA', 'TypeF', 'TypeG', 'TypeK', 'TypeM', 'NotApplicable'],
mv.spectralType = {}
for (let i = 0; i < mv.spectralTypes.length; i++) {
  // Make the map from name to index
  mv.spectralType[mv.spectralTypes[i]] = i
}

mv.worldClasses = ['Asteroidal', 'Lunar', 'Terrestrial', 'Jovian', 'Cometary', 'Europan', 'Panthalassic', 'Neptunian', 'Ring', 'AsteroidBelt'],
mv.worldClass = {}
for (let i = 0; i < mv.worldClasses.length; i++) {
  // Make the map from name to index
  mv.worldClass[mv.worldClasses[i]] = i
}

// Only some world classes have actual spherical bodies associated with them. Some are placeholders for diffuse things
mv.hasBody = function(worldClassNum) {
    if (worldClassNum == mv.worldClass['Ring'] || worldClassNum == mv.worldClass['AsteroidBelt']) {
        // These are diffuse
        return false
    }

    // Everybody else is a real world
    return true
}


/////////////
// Token utilities
/////////////

// Here are the constants from the ownership registry, for packing and unpacking token IDs.

// Define the types of tokens that can exist
mv.TOKEN_TYPE_SECTOR = 0
mv.TOKEN_TYPE_SYSTEM = 1
mv.TOKEN_TYPE_PLANET = 2
mv.TOKEN_TYPE_MOON = 3
// Land tokens are a range of type field values.
// Land tokens of the min type use one trixel field
mv.TOKEN_TYPE_LAND_MIN = 4
mv.TOKEN_TYPE_LAND_MAX = 31

// Define the packing format
mv.TOKEN_SECTOR_X_SHIFT = 5
mv.TOKEN_SECTOR_X_BITS = 16
mv.TOKEN_SECTOR_Y_SHIFT = mv.TOKEN_SECTOR_X_SHIFT + mv.TOKEN_SECTOR_X_BITS
mv.TOKEN_SECTOR_Y_BITS = 16
mv.TOKEN_SECTOR_Z_SHIFT = mv.TOKEN_SECTOR_Y_SHIFT + mv.TOKEN_SECTOR_Y_BITS
mv.TOKEN_SECTOR_Z_BITS = 16
mv.TOKEN_SYSTEM_SHIFT = mv.TOKEN_SECTOR_Z_SHIFT + mv.TOKEN_SECTOR_Z_BITS
mv.TOKEN_SYSTEM_BITS = 16
mv.TOKEN_PLANET_SHIFT = mv.TOKEN_SYSTEM_SHIFT + mv.TOKEN_SYSTEM_BITS
mv.TOKEN_PLANET_BITS = 16
mv.TOKEN_MOON_SHIFT = mv.TOKEN_PLANET_SHIFT + mv.TOKEN_PLANET_BITS
mv.TOKEN_MOON_BITS = 16
mv.TOKEN_TRIXEL_SHIFT = mv.TOKEN_MOON_SHIFT + mv.TOKEN_MOON_BITS
mv.TOKEN_TRIXEL_EACH_BITS = 3

// How many trixel fields are there
mv.TOKEN_TRIXEL_FIELD_COUNT = 27

// How many children does a trixel have?
mv.CHILDREN_PER_TRIXEL = 4
// And how many top level trixels does a world have?
mv.TOP_TRIXELS = 8

// We keep a bit mask of the high bits of all but the least specific trixel.
// None of these may be set in a valid token.
// We rely on it being left-shifted TOKEN_TRIXEL_SHIFT bits before being applied.
// Note that this has 26 1s, with one every 3 bits, except the last 3 bits are 0.
mv.TOKEN_TRIXEL_HIGH_BIT_MASK = 0x124924924924924924920

// Sentinel for no moon used (for land on a planet)
mv.MOON_NONE = 0xFFFF

// We have a function to properly hash a number or BigNumber or 0x string token number and nonce, for making claims
mv.hashTokenAndNonce = function(token, nonce) {
    token = new BigNumber(token)
    nonce = new BigNumber(nonce)
    
    // Bignums are hashed as uint256 if positive
    return Web3Utils.soliditySha3(token, nonce)
}

// We need a function to bit-shift bignums. A positive shift shifts left.
mv.shift = function(number, bits) {
  if (bits >= 0) {
    // Shift left
    return number.times(new BigNumber(2).pow(bits))
  } else {
    // Shift right
    return number.div(new BigNumber(2).pow(-bits))
  }
}

// We have a function to convert from keypaths for objects to tokens
mv.keypathToToken = function(keypath) {
  let parts = keypath.split('.')

  let token = new BigNumber(0)

  if (parts.length < 3) {
    // Token is invalid
    throw new Error('Token for keypath ' + keypath + ' cannot be constructed')
    
  }

  // Fill in the sector x, y, z
  token = token.plus(mv.shift(new BigNumber(parts[0]), mv.TOKEN_SECTOR_X_SHIFT))
  token = token.plus(mv.shift(new BigNumber(parts[1]), mv.TOKEN_SECTOR_Y_SHIFT))
  token = token.plus(mv.shift(new BigNumber(parts[2]), mv.TOKEN_SECTOR_Z_SHIFT))

  if (parts.length < 4) {
    // It's a sector (not a real token that can be claimed)
    token = token.plus(new BigNumber(mv.TOKEN_TYPE_SECTOR))
    return token
  }

  // Otherwise it has a star number
  token = token.plus(mv.shift(new BigNumber(parts[3]), mv.TOKEN_SYSTEM_SHIFT))

  if (parts.length < 5) {
    // It's a real system token. Return it as one.
    token = token.plus(new BigNumber(mv.TOKEN_TYPE_SYSTEM))
    return token
  }

  // Otherwise it has a planet number
  token = token.plus(mv.shift(new BigNumber(parts[4]), mv.TOKEN_PLANET_SHIFT))

  if (parts.length < 6) {
    // It's a real planet token. Return it as one.
    token = token.plus(new BigNumber(mv.TOKEN_TYPE_PLANET))
    return token
  }

  // Otherwise it has a moon number, or -1 in the keypath to represent that it is land on a planet.
  // TODO: should we use a different signifier for land?
  if (parts[5] == -1) {
    // Planet land. Mark it as no moon.
    token = token.plus(mv.shift(new BigNumber(mv.MOON_NONE), mv.TOKEN_MOON_SHIFT))
  } else {
    // A moon or moon land. Store the moon number.
    token = token.plus(mv.shift(new BigNumber(parts[5]), mv.TOKEN_MOON_SHIFT))
  }

  if (parts.length < 7) {
    // It's just the moon. This isn't a legit token if this is supposed to be planet land.
    // TODO: catch that.
    token = token.plus(new BigNumber(mv.TOKEN_TYPE_MOON))
    return token
  }

  // Otherwise this is land. Go through and translate the remaining parts directly into trixel numbers
  for (let trixel_index = 0; trixel_index < mv.TOKEN_TRIXEL_FIELD_COUNT && trixel_index + 6 < parts.length; trixel_index++) {
    // For each trixel we can have, add it in
    token = token.plus(mv.shift(new BigNumber(parts[trixel_index + 6]), mv.TOKEN_TRIXEL_SHIFT + mv.TOKEN_TRIXEL_EACH_BITS * trixel_index));
  }

  // Set the type to the appropriate granularity of land
  token = token.plus(new BigNumber(mv.TOKEN_TYPE_LAND_MIN + (parts.length - 7)))

  // Spit out the constructed token
  return token;

}








