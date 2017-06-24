function promiseify(toCall) {
  return new Promise(function (resolve, reject) {
    toCall(function(err, result) {
      if (err) {
        reject(err)
      } else {
        resolve(result)
      }
    })
  })
}

let REAL_FBITS = 40;

function fromReal(real) {
  // Convert from 40 bit fixed point
  return real.dividedBy(web3.toBigNumber(2).toPower(REAL_FBITS)).toNumber()
}

let objectClasses = ['Supergiant', 'Giant', 'MainSequence', 'WhiteDwarf', 'NeutronStar', 'BlackHole']
let spectralTypes = ['TypeO', 'TypeB', 'TypeA', 'TypeF', 'TypeG', 'TypeK', 'TypeM', 'NotApplicable']


window.addEventListener('load', function() {

  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (typeof web3 !== 'undefined') {
    // Use Mist/MetaMask's provider
    window.web3 = new Web3(web3.currentProvider)
  } else {
    console.log('No web3? You should consider trying MetaMask!')
    // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"))
  }

  // Now you can start your app & access web3 freely:
  startApp()

})

async function startApp() {
  console.log("Running on network " + await promiseify(web3.version.getNetwork))
  // Load up the MRVToken
  let MRVToken = TruffleContract(await $.getJSON('contracts/MRVToken.json'))
  MRVToken.setProvider(web3.currentProvider)
  window.MRVTokenInstance = await MRVToken.deployed()
  
  // And the Macroverse Star Generator
  let MacroverseStarGenerator = TruffleContract(await $.getJSON('contracts/MacroverseStarGenerator.json'))
  MacroverseStarGenerator.setProvider(web3.currentProvider)
  window.MacroverseStarGeneratorInstance = await MacroverseStarGenerator.deployed()
  
  // And the Macroverse Star Registry
  let MacroverseStarRegistry = TruffleContract(await $.getJSON('contracts/MacroverseStarRegistry.json'))
  MacroverseStarRegistry.setProvider(web3.currentProvider)
  window.MacroverseStarRegistryInstance = await MacroverseStarRegistry.deployed()
  
  console.log("Balance: " + await MRVTokenInstance.balanceOf(web3.eth.accounts[0]))
  
  let starCount = (await MacroverseStarGeneratorInstance.getSectorObjectCount.call(0, 0, 0)).toNumber()
  console.log("Stars in origin sector: ", starCount)
  
  let starPromises = []
    
  let foundPlanets = false;
  
  for (let star = 0; star < starCount; star++) {
    
    starPromises.push(async function() {
    
      // Generate each star
      // Make a seed
      let seed = await MacroverseStarGeneratorInstance.getSectorObjectSeed.call(0, 0, 0, star)
      
      // Decide on a position
      let [ x, y, z] = await MacroverseStarGeneratorInstance.getObjectPosition.call(seed)
      x = fromReal(x)
      y = fromReal(y)
      z = fromReal(z)
      
      // Then get the class
      let objClass = (await MacroverseStarGeneratorInstance.getObjectClass.call(seed)).toNumber()
      // Then make the spectral type
      let objType = (await MacroverseStarGeneratorInstance.getObjectSpectralType.call(seed, objClass)).toNumber()
      // Then make the mass
      let objMass = fromReal(await MacroverseStarGeneratorInstance.getObjectMass.call(seed, objClass, objType))
      // And decide if it has planets
      let hasPlanets = await MacroverseStarGeneratorInstance.getObjectHasPlanets.call(seed, objClass, objType)
      
      console.log("Star " + star + " at " + x + "," + y + "," + z + " ly is a " + objectClasses[objClass] + " " + spectralTypes[objType] + " of " + objMass + " solar masses" + (hasPlanets ? " with planets" : ""))
      
      if (hasPlanets) {
        foundPlanets = true;
      }
      
    }())
  }
  
  await Promise.all(starPromises)
  
}