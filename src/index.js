// index.js: Main file for the Macroverse JavaScript library

// The code in this file helps you interact with the Macroverse contracts by
// defining JS equivalents or counterparts to some of the on-chain Solidity
// code.

const BigNumber = require('bignumber.js')

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
mv.degrees = require('radians-degrees');
// And back again
mv.radians = require('degrees-radians');

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
// The luminosity of the sun, in watts
mv.SOLAR_LUMINOSITY = 3.828E26

// A Julian year is exactly 365.25 days and is our basic time unit.
// We think about orbits in terms of radians per Julian year.
mv.JULIAN_YEAR = 365.25 * 24 * 60 * 60;
// A siderial year is about 365.25636 seconds and is Earth's orbital period
mv.SIDERIAL_YEAR = 365.25636 * 24 * 60 * 60
// A day is a day (24 hours of 60 minutes of 60 seconds)
mv.DAY = 24 * 60 * 60

// When did the Macroverse world start, in Unix time?
// Subtract from block timestamp to get seconds since epoch for block.
mv.EPOCH = 1518671883

// Convert a Unix-time block timestamp to Julian years since Macroverse epoch
mv.yearsSinceEpoch = function(unixTime) {
  return (unixTime - mv.EPOCH) / mv.JULIAN_YEAR;
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

mv.planetClasses = ['Asteroidal', 'Lunar', 'Terrestrial', 'Jovian', 'Cometary', 'Europan', 'Panthalassic', 'Neptunian', 'Ring', 'AsteroidBelt'],
mv.planetClass = {}
for (let i = 0; i < mv.planetClasses.length; i++) {
  // Make the map from name to index
  mv.planetClass[mv.planetClasses[i]] = i
}








