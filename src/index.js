// index.js: Main file for the Macroverse JavaScript library

// The code in this file helps you interact with the Macroverse contracts by
// defining JS equivalents or counterparts to some of the on-chain Solidity
// code.

// TODO: load web3 somehow if not already available

var mv = module.exports

mv.REAL_FBITS = 40
mv.REAL_ONE = web3.toBigNumber(2).toPower(mv.REAL_FBITS)

mv.fromReal = function(real) {
  // Convert from 40 bit fixed point
  return real.dividedBy(REAL_ONE).toNumber()
}

mv.objectClasses = ['Supergiant', 'Giant', 'MainSequence', 'WhiteDwarf', 'NeutronStar', 'BlackHole']
mv.objectClass = {
  'Supergiant': 0,
  'Giant': 1,
  'MainSequence': 2,
  'WhiteDwarf': 3,
  'NeutronStar': 4,
  'BlackHole': 5
}

mv.spectralTypes = ['TypeO', 'TypeB', 'TypeA', 'TypeF', 'TypeG', 'TypeK', 'TypeM', 'NotApplicable'],
mv.spectralType = {
  'TypeO': 0,
  'TypeB': 1,
  'TypeA': 2,
  'TypeF': 3,
  'TypeG': 4,
  'TypeK': 5,
  'TypeM': 6,
  'NotApplicable': 7
}
