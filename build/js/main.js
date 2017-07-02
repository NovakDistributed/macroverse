// Turn an err, result-callback-taking function into a promise for the result of calling it
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

// Make a promise time out in the given number of ms
function timeoutPromise(time, promise) {
  return Promise.race([promise, new Promise(function(resolve, reject) {
    setTimeout(function() {
      reject('Timout!')
    }, time)
  })])
}

// How long should we wait for a promise when loading stars?
let MAX_WAIT_TIME = 10000

let REAL_FBITS = 40

function fromReal(real) {
  // Convert from 40 bit fixed point
  return real.dividedBy(web3.toBigNumber(2).toPower(REAL_FBITS)).toNumber()
}

let objectClasses = ['Supergiant', 'Giant', 'MainSequence', 'WhiteDwarf', 'NeutronStar', 'BlackHole']
let spectralTypes = ['TypeO', 'TypeB', 'TypeA', 'TypeF', 'TypeG', 'TypeK', 'TypeM', 'NotApplicable']

// See http://www.isthe.com/chongo/tech/astro/HR-temp-mass-table-byhrclass.html for a nice table, also accounting for object class (IV/III/etc.) and 0-9 subtype.
let typeToColor = {
  'TypeO': [144, 166, 255],
  'TypeB': [156, 179, 255],
  'TypeA': [179, 197, 255],
  'TypeF': [218, 224, 255],
  'TypeG': [255, 248, 245],
  'TypeK': [255, 225, 189],
  'TypeM': [255, 213, 160],
  'NotApplicable': [128, 128, 128]
}


// Startup function from Metamask documentation
// Ought to work with Metamask or with testrpc or geth on the local machine
window.addEventListener('load', function() {
  // We are running this file, so async/await code is parseable
  $('#haveAsync').text("Your browser supports async/await.")
  
  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (typeof web3 !== 'undefined') {
    // Use Mist/MetaMask's provider
    $('#web3type').text('MetaMask, Mist, or other in-browser web3 provider.')
    window.web3 = new Web3(web3.currentProvider)
  } else {
    console.log('No browser-provided web3; falling back to local node account 0 if present')
    $('#web3type').text('RPC from browser against http://localhost:8545.')
    // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"))
  }

  // Now you can start your app & access web3 freely:
  startApp()

})

// Represents a cache over the MacroverseStarGenerator.
class StarCache {
  // Construct a cache in front of a TruffleContract for the MacroverseStarGenerator
  constructor(MacroverseStarGeneratorInstance) {
    // Save a reference to the backing MacroverseStarGenerator
    this.generator = MacroverseStarGeneratorInstance
    
    // Maps from string paths to object
    this.cache = {}
  }
  
  // Get the given object from the given sector, from either the blockchain or the cache.
  async getObject(sectorX, sectorY, sectorZ, objectNumber) {
    // Make a string path for the object
    let path = sectorX + ',' + sectorY + ',' + sectorZ + '/' + objectNumber
    
    if (!this.cache.hasOwnProperty(path)) {
      
      // Make a new object
      let obj = {number: objectNumber, sectorX, sectorY, sectorZ}
      
      for (let tryNumber = 0; tryNumber < 10; tryNumber++) {
        
        try {
          // Work out the seed
          obj.seed = await timeoutPromise(MAX_WAIT_TIME, this.generator.getSectorObjectSeed.call(sectorX, sectorY, sectorZ, objectNumber))
          
          // Decide on a position
          let [ x, y, z] = await timeoutPromise(MAX_WAIT_TIME, this.generator.getObjectPosition.call(obj.seed))
          obj.x = fromReal(x)
          obj.y = fromReal(y)
          obj.z = fromReal(z)
          
          obj.objClass = (await timeoutPromise(MAX_WAIT_TIME, this.generator.getObjectClass.call(obj.seed))).toNumber()
          obj.objType = (await timeoutPromise(MAX_WAIT_TIME, this.generator.getObjectSpectralType.call(obj.seed, obj.objClass))).toNumber()
          
          obj.hasPlanets = await timeoutPromise(MAX_WAIT_TIME, this.generator.getObjectHasPlanets.call(obj.seed, obj.objClass, obj.objType))
          
          obj.objMass = fromReal(await timeoutPromise(MAX_WAIT_TIME, this.generator.getObjectMass.call(obj.seed, obj.objClass, obj.objType)))
          
          // Save it
          this.cache[path] = obj
          console.log('Successfully loaded star ' + path)
          break
          
        } catch (err) {
          // Ignore errors (probably lost RPC requests) and retry from the beginning
          console.log('Retrying star ' + path + ' try ' + tryNumber + ' after error: ', err)
        }
      }
    }
    
    if (!this.cache.hasOwnProperty(path)) {
      throw new Error('Unable to load ' + path + ' from Ethereum blockchain. Check your RPC node!')
    }
    
    return this.cache[path]
  }
  
  async getObjectCount(sectorX, sectorY, sectorZ) {
    // Make a string path for just the sector
    let path = sectorX + ',' + sectorY + ',' + sectorZ
    if (!this.cache.hasOwnProperty(path)) {
      // If we haven't counted the stars in the sector yet, go do it.
      this.cache[path] = (await this.generator.getSectorObjectCount.call(sectorX, sectorY, sectorZ)).toNumber()
    }
    return this.cache[path]
  }
  
}

async function startApp() {
  
  console.log(web3)
  
  let network = await promiseify(web3.version.getNetwork)
  console.log("Running on network " + network)
  $('#network').text(network)
  
  let address0 = web3.eth.accounts[0]
  $('#account').text(address0)
  
  // Start up the 3D engine and get the scene
  let scene = start3D();
  
  // Load up the MRVToken
  let MRVToken = TruffleContract(await $.getJSON('contracts/MRVToken.json'))
  MRVToken.setProvider(web3.currentProvider)
  let MRVTokenInstance = await MRVToken.deployed()
  
  // And the Macroverse Star Generator
  let MacroverseStarGenerator = TruffleContract(await $.getJSON('contracts/MacroverseStarGenerator.json'))
  MacroverseStarGenerator.setProvider(web3.currentProvider)
  let MacroverseStarGeneratorInstance = await MacroverseStarGenerator.deployed()
  
  // And the Macroverse Star Registry
  let MacroverseStarRegistry = TruffleContract(await $.getJSON('contracts/MacroverseStarRegistry.json'))
  MacroverseStarRegistry.setProvider(web3.currentProvider)
  let MacroverseStarRegistryInstance = await MacroverseStarRegistry.deployed()
  
  // This balance has to be at least 100 * 10^18 for things to work, assuming the minimum balance requirement hasn't been changed
  let balance = web3.fromWei(await MRVTokenInstance.balanceOf(web3.eth.accounts[0]), "ether")
  console.log("Balance: " + balance)
  $('#balance').text(balance)
  
  // Slap a chace in front of the MacroverseStarGenerator
  let cache = new StarCache(MacroverseStarGeneratorInstance)
  
  let starCount = await cache.getObjectCount(0, 0, 0)
  console.log("Stars in origin sector: ", starCount)
  
  let starPromises = []
  
  for (let star = 0; star < starCount; star++) {
    
    starPromises.push(async function() {
      // Go get the star properties
      let obj = await cache.getObject(0, 0, 0, star)
      
      // Get a material for this star
      // TODO: cache?
      let material = getStarMaterial(scene, spectralTypes[obj.objType])
      
      // Make a 3d model to represent the star in the 3d scene
      // Make it glow if it's not a black hole
      let starMesh = addStar(scene, obj.x, obj.y, obj.z, Math.pow(obj.objMass, 1/4), material, objectClasses[obj.objClass] != 'BlackHole')
      
      starMesh.onPick = () => {
        // When someone clicks on a star, tell them about it.
        showStarInfo(obj)
      }
      
    }())
    
  }
  
  await Promise.all(starPromises)
  
  console.log('All stars downloaded successfully.')
  
}

// Get the material that a star or object ought to use, given the class name of its spectral type
function getStarMaterial(scene, spectralType) {
  // Make a material
  let material = new BABYLON.StandardMaterial("starMaterial", scene)
  
  let [r, g, b] = typeToColor[spectralType]
  let color = new BABYLON.Color3(r/255, g/255, b/255)
  
  // Say it should be black with respect to lights
  material.diffuseColor = new BABYLON.Color3(0, 0, 0)
  material.specularColor = material.diffuseColor
  
  // Say it should glow this color
  material.emissiveColor = color
  
  return material
}

// Add a star to the given 3d scene at the given x, y, z coordinates, with the given sol-relative size and material.
function addStar(scene, x, y, z, size, material, shouldGlow) {
  // Make a 3-subdivisdion, tiny sphere
  let starSphere = BABYLON.Mesh.CreateSphere("", 12, size, scene)
  // Center the 25-ly sector on the origin
  starSphere.position.x = x - 12.5
  starSphere.position.y = y - 12.5
  starSphere.position.z = z - 12.5
  // Set its material
  starSphere.material = material
  
  if (shouldGlow) {
    // Now add some particles to it
    let particleSystem = new BABYLON.ParticleSystem("", 2000, scene)
    particleSystem.emitter = starSphere
    
    // Give them a texture
    // From <https://opengameart.org/node/8291> under CC0
    particleSystem.particleTexture = new BABYLON.Texture("img/nova_1.png", scene)
    
    // Spawn them in a box
    particleSystem.minEmitBox = new BABYLON.Vector3(-size/4, -size/4, -size/4)
    particleSystem.maxEmitBox = new BABYLON.Vector3(size/4, size/4, size/4)
    
    // Aim them everywhere
    particleSystem.direction1 = new BABYLON.Vector3(-size/4, -size/4, -size/4)
    particleSystem.direction2 = new BABYLON.Vector3(size/4, size/4, size/4)
    
    // And make size scale with star
    particleSystem.minSize = size * 0.6
    particleSystem.maxSize = size * 1.5
    
    // Blend from star color to black
    particleSystem.color1 = particleSystem.colorDead
    particleSystem.color2 = material.emissiveColor
    //particleSystem.colorDead = new BABYLON.Color4(0.0, 1.0, 1.0, 1.0)
    
    // Have lots of particles
    particleSystem.emitRate = 150
    
    // Don't have gravity in space
    particleSystem.gravity = new BABYLON.Vector3(0, 0, 0);
    
    particleSystem.start()
  }
  
  return starSphere
}

// Display the information on the fully-realized star object in the info panel
function showStarInfo(obj) {
  $('.starinfoplaceholder').hide()

  // TODO: Replace all this nonsense with ractive
  $('#sector').text(obj.sectorX + ', ' + obj.sectorY + ', ' + obj.sectorZ)
  $('#number').text(obj.number)
  $('#coordinates').text(obj.x.toFixed(2) + ', ' + obj.y.toFixed(2) + ', ' + obj.z.toFixed(2))
  $('#objClass').text(objectClasses[obj.objClass])
  $('#objType').text(spectralTypes[obj.objType])
  $('#mass').text(obj.objMass.toFixed(4))
  $('#planets').text(obj.hasPlanets ? 'Yes' : 'No')
  $('#seed').text(obj.seed)
  
  $('.starinfo').show()
}

// This starts up the Babylon 3d engine and draws stuff.
// Returns the scene for further manipulation
function start3D() {
  // Get the canvas element from our HTML below
  let canvas = document.querySelector("#renderCanvas")
  // Load the BABYLON 3D engine
  let engine = new BABYLON.Engine(canvas, true)
  
  // Now create a basic Babylon Scene object
  let scene = new BABYLON.Scene(engine)
  // Make the background off-black
  scene.clearColor = new BABYLON.Color3(0.1, 0.1, 0.1)

  // Make the camera an ArcRotateCamera that can be rotated around the scene to look at it
  // Put it just outside the sector, and target 0,0,0.
  let camera = new BABYLON.ArcRotateCamera("camera1", 0.3, 1.5, 50, new BABYLON.Vector3(0, 0, 0), scene)
  // Control it from the canvas
  camera.attachControl(canvas, false)
  
  // Light the scene from above
  let light = new BABYLON.HemisphericLight("light1", new BABYLON.Vector3(0, 1, 0), scene)
  light.intensity = 1
  
  // Put a box in to define the sector
  let box = BABYLON.Mesh.CreateBox("sector", 25, scene)
  // Make it wireframe
  box.material = new BABYLON.StandardMaterial("wireframe", scene)
  box.material.wireframe = true
  box.material.diffuseColor = new BABYLON.Color3(0, 0, 0)
  box.material.specularColor = box.material.diffuseColor
  box.material.emissiveColor = new BABYLON.Color3(0.0, 1.0, 0.0)
  box.material.alpha = 0.1
  box.isPickable = false
  
  // Register a render loop to repeatedly render the scene
  engine.runRenderLoop(function () {
     scene.render()
  })
  
  // Watch for browser/canvas resize events
  window.addEventListener("resize", function () {
     engine.resize()
  })
  
  // Await clicks
  // TODO: don't count the ends of drags as clicks!
  window.addEventListener("click", function () {
    let pickResult = scene.pick(scene.pointerX, scene.pointerY)
     
    if (pickResult.hit && pickResult.pickedMesh && pickResult.pickedMesh.onPick) {
      // Run a function when we pick this thing.
      pickResult.pickedMesh.onPick()
    }
  })
  
  // Return the scene for use elsewhere
  return scene
}