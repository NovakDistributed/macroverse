// index.js: Main file for the Macroverse JavaScript library

// The code in this file helps you interact with the Macroverse contracts by
// defining JS equivalents or counterparts to some of the on-chain Solidity
// code.

const BN = require('bn.js')

// We need this for the Solidity-alike hashing functions
const Web3Utils = require('web3-utils')

var mv = module.exports

mv.REAL_FBITS = 40
mv.REAL_ONE = (new BN(2)).pow(new BN(mv.REAL_FBITS))

mv.fromReal = function(real) {
  // Treat as a BigNumber
  real = new BN(real.toString(10))

  // Break up real and fractional parts
  let ipart = parseInt(real.div(mv.REAL_ONE).toString())
  let fpart = parseInt(real.mod(mv.REAL_ONE).toString())
  // Do the actual conversion  from 40 bit fixed point in floats
  return ipart + fpart / Math.pow(2, mv.REAL_FBITS)
}

mv.toReal = function(float) {
  // Convert to 40 bit fixed point, with 88 integral bits, one of which is sign.
  
  if (isNaN(float)) {
    throw new Error("NaN cannot be represented in fixed-point!")
  }
  
  if (Math.log2(Math.abs(float)) >= 87) {
    throw new Error("Magnitude of " + float + " is too large for 88 bit signed int!")
  }

  // Split into integer and fractional parts, upshift, and convert to digit strings
  let ipart = toDigits(Math.trunc(float))
  let fpart = toDigits((float - Math.trunc(float)) * Math.pow(2, mv.REAL_FBITS))
  
  // Build the BN
  return mv.REAL_ONE.mul(new BN(ipart)).add(new BN(fpart))
}

// Spit out all the digits (losing precision) for a float beyond the 20
// <num>.toFixed natively gives us.
// Taken from https://stackoverflow.com/a/1685917
function toDigits(x) {
  if (Math.abs(x) < 1.0) {
    let e = parseInt(x.toString().split('e-')[1])
    if (e) {
        x *= Math.pow(10,e-1)
        x = '0.' + (new Array(e)).join('0') + x.toString().substring(2)
    }
  } else {
    let e = parseInt(x.toString().split('+')[1])
    if (e > 20) {
        e -= 20;
        x /= Math.pow(10,e);
        x += (new Array(e+1)).join('0')
    }
  }
  return x
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

// How long does it take for a commitment to expire, as a multiple of the maturation time?
// This is hardcoded in the registry, but the maturation time is configurable at registry deployment.
mv.COMMITMENT_MAX_WAIT_FACTOR = 7

// We have a function to properly hash a number or BN or 0x string token number and nonce, for making claims
mv.hashTokenAndNonce = function(token, nonce) {
  token = new BN(token)
  if (typeof nonce == 'string' && nonce.startsWith('0x')) {
    // It is in hex. Parse to BN as base 16 without 0x.
    nonce = new BN(nonce.substr(2), 16)
  } else {
    // Hope we can just parse it.
    nonce = new BN(nonce)
  }
    
  // Bignums are hashed as uint256 if positive
  return Web3Utils.soliditySha3(token, nonce)
}

// We have a function to properly hash a token-and-nonce hash and an address, to get the key to look up a claim
mv.getClaimKey = function(commitment_hash, owner_address) {
    return Web3Utils.soliditySha3(commitment_hash, owner_address)
}

// Convert a signed number to an unsigned bit pattern BN of the same bit width.
mv.signedToUnsigned = function(number, width) {
  number = new BN(number)
  width = new BN(width)
  if (number.ltn(0)) {
    // Compute a two's complement representation.
    // Add our negative number to (i.e. subtract from) 2^width
    return new BN(2).pow(width).add(number)
  } else {
    return number
  }
}

// Convert an unsigned bit pattern to a signed BN of the same bit width.
mv.unsignedToSigned = function(number, width) {
  number = new BN(number)
  width = new BN(width)
  let highBit = new BN(2).pow(width.sub(new BN(1)))
  if (highBit.lte(number)) {
    // Number should be negative. Subtract the offset.
    return number.sub(highBit.mul(new BN(2)))
  } else {
    return number
  }
}

// We need a function to bit-shift bignums. A positive shift shifts left.
// Only works correctly (real bitwise shift) on unsigned numbers.
// Bits can't be a BN.
mv.shift = function(number, shiftBits) {
  // Make sure arguments have the methods BN requires
  number = new BN(number)
  if (shiftBits >= 0) {
    // Shift left
    return number.shln(shiftBits)
  } else {
    // Shift right
    return number.shrn(shiftBits)
  }
}

// We have a function to convert from keypaths for objects to tokens.
// Tokens are represented as stringified numbers.
mv.keypathToToken = function(keypath) {
  let parts = keypath.split('.')

  let token = new BN(0)

  if (parts.length < 3) {
    // Token is invalid
    throw new Error('Token for keypath ' + keypath + ' cannot be constructed')
    
  }

  // Fill in the sector x, y, z
  token = token.add(mv.shift(mv.signedToUnsigned(parts[0], mv.TOKEN_SECTOR_X_BITS), mv.TOKEN_SECTOR_X_SHIFT))
  token = token.add(mv.shift(mv.signedToUnsigned(parts[1], mv.TOKEN_SECTOR_Y_BITS), mv.TOKEN_SECTOR_Y_SHIFT))
  token = token.add(mv.shift(mv.signedToUnsigned(parts[2], mv.TOKEN_SECTOR_Z_BITS), mv.TOKEN_SECTOR_Z_SHIFT))

  if (parts.length < 4) {
    // It's a sector (not a real token that can be claimed)
    token = token.add(new BN(mv.TOKEN_TYPE_SECTOR))
    return token.toString()
  }

  // Otherwise it has a star number (non-negative)
  token = token.add(mv.shift(new BN(parts[3]), mv.TOKEN_SYSTEM_SHIFT))

  if (parts.length < 5) {
    // It's a real system token. Return it as one.
    token = token.add(new BN(mv.TOKEN_TYPE_SYSTEM))
    return token.toString()
  }

  // Otherwise it has a planet number (non-negative)
  token = token.add(mv.shift(new BN(parts[4]), mv.TOKEN_PLANET_SHIFT))

  if (parts.length < 6) {
    // It's a real planet token. Return it as one.
    token = token.add(new BN(mv.TOKEN_TYPE_PLANET))
    return token.toString()
  }

  // Otherwise it has a moon number, or -1 in the keypath to represent that it is land on a planet.
  // TODO: should we use a different signifier for land?
  if (parts[5] == -1) {
    // Planet land. Mark it as no moon.
    token = token.add(mv.shift(new BN(mv.MOON_NONE), mv.TOKEN_MOON_SHIFT))
  } else {
    // A moon or moon land. Store the moon number.
    token = token.add(mv.shift(new BN(parts[5]), mv.TOKEN_MOON_SHIFT))
  }

  if (parts.length < 7) {
    // It's just the moon. This isn't a legit token if this is supposed to be planet land.
    // TODO: catch that.
    token = token.add(new BN(mv.TOKEN_TYPE_MOON))
    return token.toString()
  }

  // Otherwise this is land. Go through and translate the remaining parts directly into trixel numbers
  for (let trixel_index = 0; trixel_index < mv.TOKEN_TRIXEL_FIELD_COUNT && trixel_index + 6 < parts.length; trixel_index++) {
    // For each trixel we can have, add it in
    token = token.add(mv.shift(new BN(parts[trixel_index + 6]), mv.TOKEN_TRIXEL_SHIFT + mv.TOKEN_TRIXEL_EACH_BITS * trixel_index));
  }

  // Set the type to the appropriate granularity of land
  token = token.add(new BN(mv.TOKEN_TYPE_LAND_MIN + (parts.length - 7)))
    
  // Spit out the constructed token
  return token.toString()

}

// To parse tokens we need a way to get bit ranges
// lowest and count cannot be BNs
mv.getBits = function(num, lowest, count) {
  num = new BN(num)
  // Shift off the too-low bits
  let cutoff = num.shrn(lowest)
  // Then mask off bits at count or higher
  return cutoff.maskn(count)
}

// And we have a function to convert tokens to keypaths.
// Tokens may be strings or BNs.
mv.tokenToKeypath = function(token) {
  // Tolerate string tokens by converting to BN
  token = new BN(token.toString())
  
  let type = mv.getBits(token, 0, 5).toNumber()

  // We always have sector X, Y, Z.
  // Make sure to interpret the values we get as signed.
  let sectorX = mv.unsignedToSigned(mv.getBits(token, mv.TOKEN_SECTOR_X_SHIFT, mv.TOKEN_SECTOR_X_BITS), mv.TOKEN_SECTOR_X_BITS).toNumber()
  let sectorY = mv.unsignedToSigned(mv.getBits(token, mv.TOKEN_SECTOR_Y_SHIFT, mv.TOKEN_SECTOR_Y_BITS), mv.TOKEN_SECTOR_Y_BITS).toNumber()
  let sectorZ = mv.unsignedToSigned(mv.getBits(token, mv.TOKEN_SECTOR_Z_SHIFT, mv.TOKEN_SECTOR_Z_BITS), mv.TOKEN_SECTOR_Z_BITS).toNumber()

  let keypath = sectorX + '.' + sectorY + '.' + sectorZ

  if (type < mv.TOKEN_TYPE_SYSTEM) {
    return keypath
  }

  // If we are star or more specific we have a star
  let star = mv.getBits(token, mv.TOKEN_SYSTEM_SHIFT, mv.TOKEN_SYSTEM_BITS).toNumber()
  keypath += '.' + star

  if (type < mv.TOKEN_TYPE_PLANET) {
    return keypath
  }

  // If we are planet or more specific we have a planet
  let planet = mv.getBits(token, mv.TOKEN_PLANET_SHIFT, mv.TOKEN_PLANET_BITS).toNumber()
  keypath += '.' + planet

  if (type < mv.TOKEN_TYPE_MOON) {
    return keypath
  }

  // If we are moon or more specific we *may* have a moon, or -1 (0xFFFF).
  // Either way it goes in the keypath.
  let moon = mv.getBits(token, mv.TOKEN_MOON_SHIFT, mv.TOKEN_MOON_BITS).toNumber()
  if (moon == 0xffff) {
    moon = -1
  }
  keypath += '.' + moon

  // If we are land, we have some number of 3-bit trixels

  if (type < mv.TOKEN_TYPE_LAND_MIN) {
    return keypath
  }

  for (let i = 0; i < (type - mv.TOKEN_TYPE_LAND_MIN + 1); i++) {
    let trixel = mv.getBits(token, mv.TOKEN_TRIXEL_SHIFT + i * mv.TOKEN_TRIXEL_EACH_BITS, mv.TOKEN_TRIXEL_EACH_BITS).toNumber()
    keypath += '.' + trixel
  }

  return keypath
}

// Format a number as an ordinal (1st, 23rd, etc.)
mv.ordinal = function(i) {
  let baseNumber = i.toString()
  let suffix = undefined
  switch(baseNumber) {
  case '11':
    // Fall through
  case '12':
    // Fall through
  case '13':
    // Teens are special
    suffix = 'th'
    break
  default:
    switch(baseNumber[baseNumber.length - 1]) {
    case '1':
      suffix = 'st'
      break
    case '2':
      suffix = 'nd'
      break
    case '3':
      suffix = 'rd'
      break
    default:
      suffix = 'th'
      break
    }
  }

  // We don't go up past 100 to get to e.g. one hundred and eleventh

  return baseNumber + suffix
}

// Format a number as a Roman numeral
mv.roman = function(i) {
  return ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX'][i]
}

// Format a number as a lowercase moon letter.
mv.letter = function(i) {
  return ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'][i]
}

// Format a sector for display given its coordinates
mv.formatSector = function(x, y, z) {
  return '(' + x + ',' + y + ',' + z + ')'
}

// Format a star for display given its sector coordinates and number
mv.formatStar = function(x, y, z, s) {
  return mv.formatSector(x, y, z) + '::' + (parseInt(s) + 1)
}

// Format a planet for display given its sector coordinates, star number, and planet number
mv.formatPlanet = function(x, y, z, s, p) {
  return mv.formatStar(x, y, z, s) + ' ' + roman(parseInt(p))
}

// Format a moon for display given its sector coordinates and star, planet, and moon numbers
mv.formatMoon = function(x, y, z, s, p, m) {
  return mv.formatPlanet(x, y, z, s, p) + letter(parseInt(m))
}

// Turn a keypath into a human-readable description
mv.keypathToDesignator = function(keypath) {

  let parts = keypath.split('.')

  if (parts.length < 3) {
    // Token is invalid
    throw new Error('Designator for keypath ' + keypath + ' cannot be constructed')
  }
  
  let x = parts[0]
  let y = parts[1]
  let z = parts[2]
  
  if (parts.length < 4) {
    // It's a sector (not a real token that can be claimed)
    return mv.formatSector(x, y, z)
  }
  
  // It has a star
  let s = parts[4]

  if (parts.length < 5) {
    // It's a system.
    return mv.formatStar(x, y, z, s)
  }
  
  // It has a planet
  let p = parts[5]

  if (parts.length < 6) {
    // It's a planet
    return mv.formatPlanet(x, y, z, s, p)
  }

  let m = parts[6]

  if (parts.length < 7) {
    // It's a moon
    return mv.formatMoon(x, y, z, s, p, m)
  }
  
  // It's land
  return 'Land'
}

// Generate a string nonce as a hex number (0x...) of up to 256 bits.
mv.generateNonce = function() {
  if (typeof window !== 'undefined' && typeof window.crypto !== 'undefined') {
    // Try the web crypto API
    let nonce = new Uint8Array(32)
    window.crypto.getRandomValues(nonce)
    // Convert to hex string
    // See https://stackoverflow.com/a/39225475
    return '0x' + nonce.reduce((memo, i) => memo + ('0' + i.toString(16)).slice(-2), '')
  } else {
    // Try Node crypto
    const crypto = require('crypto')
    let nonce = crypto.randomBytes(32)
    return '0x' + nonce.toString('hex')
  }
}

// Determine if a keypath is land
mv.keypathIsLand = function(keypath) {
  let parts = keypath.split('.')

  // It is land if it is under a moon, or if it has a non-final moon field that
  // is -1 (no moon, land on parent planet).
  // Moons are at depth 6 (x, y, z, star, planet, moon)
  return (parts.length > 6 || (parts.length == 6 && parts[4] == -1))
}

// Minimum deposit information must be read from the chain via the contract.

// We need a function to advance time.
// Only works on Truffle testnet, but we use it in some tests.
mv.advanceTime = function(minutes) {
  return new Promise(function (resolve, reject) {
    web3.currentProvider.send({
      jsonrpc: "2.0",
      method: "evm_increaseTime",
      params: [60 * minutes],
      id: new Date().getTime()
    }, function(err, result) {
      if (err) {
        reject(err)
      } else {
        resolve(result)
      }
    })
  })
}








