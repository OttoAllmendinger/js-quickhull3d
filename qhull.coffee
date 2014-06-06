#### three.js boilerplate
#
# Just some generic setup to get a 3d fullscreen display
#

SHOW_STATS = false

if !Detector.webgl
  Detector.addWebGLMessage()

init = ->
  bgColor = 0xeeeeee

  container = document.getElementById 'container'

  camera = camera = new THREE.PerspectiveCamera(
    27, window.innerWidth / window.innerHeight, 5, 5500
  )
  camera.position.z = 3750


  scene = new THREE.Scene
  scene.fog = new THREE.Fog bgColor, 3000, 5000

  renderer = new THREE.WebGLRenderer antialias: true
  renderer.setClearColor bgColor, 1
  renderer.setSize window.innerWidth, window.innerHeight

  container.appendChild renderer.domElement


  if SHOW_STATS
    stats = new Stats
    stats.domElement.style.position = 'absolute'
    stats.domElement.style.top = '0px'
    stats.domElement.style.right = '0px'
    container.appendChild stats.domElement


  onWindowResize = ->
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix()

    renderer.setSize window.innerWidth, window.innerHeight

  window.addEventListener 'resize', onWindowResize, false


  sceneRoot = new THREE.Object3D

  scene.add sceneRoot

  controls = new THREE.OrbitControls camera
  controls.noKeys = true
  controls.noZoom = true
  controls.noPan = true

  window.sceneRoot = sceneRoot
  window.renderer = renderer
  window.camera = camera
  window.controls = controls
  window.scene = scene
  window.stats = stats


init()

animate = ->
  requestAnimationFrame animate
  render()
  window.stats?.update()

render = ->
  window.renderer.render window.scene, window.camera


window.controls.addEventListener 'change', render




#### The Tracer
#
# A tracer option simply captures a list of scenes, consisting of faces, edges
# and points and provides methods for displaying these scenes by updating the
# ThreeJS scene graph and some DOM elements. Could be written much shorter.




# compensate for dynamic typing ;-)
isVector = (a) -> a instanceof THREE.Vector3

isFace = (t) -> t instanceof Face


class Tracer
  COLOR_EDGE_START = new THREE.Color 0xff0000
  COLOR_EDGE_END = new THREE.Color 0x0000ff

  MATERIAL_PARTICLE_DEFAULT = new THREE.ParticleBasicMaterial {
    color: 0x0000ff
    size: 40
  }

  MATERIAL_PARTICLE_RED = new THREE.ParticleBasicMaterial {
    color: 0xff0000
    size: 80
  }

  MATERIAL_ARROW = new THREE.MeshBasicMaterial {
    color: 0xff0000
  }

  MATERIAL_FACE_OUTER = new THREE.MeshBasicMaterial {
    color: 0xffff00
    transparent: true
    opacity: .5
  }

  MATERIAL_FACE_INNER = new THREE.MeshBasicMaterial {
    color: 0xff0088
    transparent: true
    opacity: .5
    side: THREE.BackSide
  }

  MATERIAL_FACE_HIGHLIGHT = new THREE.MeshBasicMaterial {
    color: 0xffff00
    transparent: true
    opacity: .75
  }

  MATERIAL_FACE_WIRE = new THREE.MeshBasicMaterial {
    color: 0x888888
    transparent: true
    opacity: .5
    wireframe: true
    depthTest: false
  }

  MATERIAL_LINE = new THREE.LineBasicMaterial {
    linewidth: 4,
    vertexColors: THREE.VertexColors
  }

  constructor: ->
    @scenes = []
    @index = 0
    @$subtitle = $('#subtitle')
    @$el = $('#trace')
    @$el.empty()
    @$el.css
      position: 'absolute'
      bottom: '1em'
      top: '0em'
      left: '1em'
      overflow: 'hidden'

  # convert Quickhull vertices to ThreeJS vertices
  getVertices: (vertices, options = {}) ->
    if not _.all(vertices, isVector)
      console.error "invalid vertex"
      return

    m = options.material or MATERIAL_PARTICLE_DEFAULT
    g = new THREE.Geometry
    g.vertices.push vertices...
    new THREE.ParticleSystem g, m

  # convert Quickhull edges to ThreeJS edges, color them as a gradient
  # to detect discontinuities
  getEdges: (edges, options = {}) ->
    if not _.all(edges, ({a, b}) -> isVector(a) and isVector(b))
      console.error "invalid edge"
      return

    obj = new THREE.Object3D
    edges.forEach ({a, b}, i) ->
      g = new THREE.Geometry
      cA = COLOR_EDGE_START.clone().lerp(COLOR_EDGE_END, i / edges.length)
      cB = COLOR_EDGE_START.clone().lerp(COLOR_EDGE_END, (i + 1) / edges.length)
      g.vertices.push a, b
      g.colors.push cA, cB
      obj.add new THREE.Line g, MATERIAL_LINE
    obj

  # convert Quickhull faces to ThreeJS faces, color front and back diffrently
  # to detect holes and faces with wrong orientation
  getFaces: (faces, options = {}) ->
    if not _.all(faces, isFace)
      console.error "invalid face"
      return

    matOuter = options.materialOuter or MATERIAL_FACE_OUTER
    matInner = options.materialInner or MATERIAL_FACE_INNER
    matWire = options.materialWire or MATERIAL_FACE_WIRE

    g = new THREE.Geometry
    _.filter(faces, (f) -> not f.deleted).forEach (f) ->
      if f.deleted then throw new Error "deleted face!"
      n = g.vertices.length
      g.vertices.push f.a, f.b, f.c
      g.faces.push new THREE.Face3 n, n+1, n+2

    obj = new THREE.Object3D
    obj.add new THREE.Mesh g, matOuter
    obj.add new THREE.Mesh g, matInner
    obj.add new THREE.Mesh g, matWire

    obj

  # create a new scene object
  trace: (message, options) ->
    obj = new THREE.Object3D

    {vertices, edges, faces,
      hiVertices, hiEdges, hiFaces,
      subtitle} = options

    if vertices
      obj.add @getVertices _.difference vertices, (hiVertices or [])

    if edges
      obj.add @getEdges _.difference edges, (hiEdges or [])

    if faces
      obj.add @getFaces _.difference faces, (hiFaces or [])

    if hiVertices
      obj.add @getVertices hiVertices, material: MATERIAL_PARTICLE_RED

    if hiFaces
      obj.add @getFaces hiFaces, materialOuter: MATERIAL_FACE_HIGHLIGHT

    $el = $("<div>").append($("<span>").text "#{@scenes.length}. #{message}")
    $el.css color: '#888'

    @$el.append $el
    @scenes.push {message, obj, $el, subtitle}

    if @scenes.length == 2
      @index = 0
      @showScene()

  showNext: ->
    if @index < @scenes.length - 1
      @index += 1
      @showScene()

  showPrev: ->
    if @index > 0
      @index -= 1
      @showScene()

  showFirst: ->
    @index = 0
    @showScene()

  showLast: ->
    @index = @scenes.length - 1
    @showScene()

  hideScene: ->
    if @s
      window.sceneRoot.remove @s.obj
      @s.$el.css color: '#888'
      @s.$el.find(".subtitle").hide()

  showScene: ->
    @hideScene()
    @s = @scenes[@index]

    if @s
      window.sceneRoot.add @s.obj
      @s.$el.css color: '#444'
      @$subtitle.html @s.subtitle or ""
      @scenes[Math.max @index - 10, 0].$el.get(0).scrollIntoView()

  clear: ->
    @hideScene()



## Quickhull

#### Tracer settings
config =
  TRACE_INITIAL: true
  TRACE_HORIZON: true
  TRACE_MANY_HORIZON_PATHS: false
  TRACE_HORIZON_STEP: false
  TRACE_TERMINATE: false
  TRACE_NEW_FACE_EACH: false
  TRACE_NEW_FACES: true


#### Face Edge
#
# Represents an edge between two points of a hull face.
# Keeps track of the face as well as the face on the opposite side, which is
# needed when stitching up faces.
class FaceLink
  constructor: (face, @a, @b) ->
    @from = face
    @to = null

  reverseOf: ({a, b}) ->
    (@a == b) and (@b == a)

#### Face
#
# Represents a hull face.
#
class Face
  constructor: (@a, @b, @c) ->
    @triangle = new THREE.Triangle a, b, c
    @plane = @triangle.plane()
    @links = [
      @linkAB = new FaceLink @, @a, @b
      @linkBC = new FaceLink @, @b, @c
      @linkCA = new FaceLink @, @c, @a
    ]

    @assignedPoints = []
    @furthest = {point: null, distance: -Infinity}

    @deleted = false
    @visited = false

  hasPoint: (point) ->
    (point == @a) or (point == @b) or (point == @c)

  distance: (point) ->
    if @hasPoint point
      0
    else
      @plane.distanceToPoint point

  # normalLine: only needed for visualization
  normalLine: ->
    m = @triangle.midpoint()
    n = @triangle.midpoint().add(
      @triangle.normal().normalize().multiplyScalar(50))
    {a: m, b: n}

  visibleBy: (point) ->
    @hasPoint(point) or (@distance(point) > 0)

  connect: (otherFace, link, otherLink) ->
    if not link.reverseOf otherLink
      throw new Error "can't connect with non-reverse link"

    link.to = otherFace
    otherLink.to = @

    link.inverse = otherLink
    otherLink.inverse = link

  assign: (point) ->
    if @hasPoint point
      true
    else
      d = @distance point
      if d >= 0
        @assignedPoints.push point

        if d > @furthest.distance
          @furthest.distance = d
          @furthest.point = point
        true

      else
        false



assignPoints = (faces, points) ->
  points.forEach (p) ->
    _.any faces, (f) -> f.assign p

checkFace = (f) ->
  error = false
  setError = (msg) ->
    console.log msg
    error = true

  if f.deleted
    return

  f.links.forEach (l, j) ->
    str = "f.links[#{j}]"
    if l.horizon == true
      setError "#{str}.horizon == true"
    if l.from != f
      setError "#{str}.from != f"
    if l.inverse.to != f
      setError "#{str}.inverse.to != f"
    if l.inverse.a != l.b
      setError "#{str}.inverse.a != l.b"
    if l.inverse.b != l.a
      setError "#{str}.inverse.b != l.a"


    backLinks = _.pluck l.to.links, 'to'
    if not _.contains backLinks, f
      setError "no reflexive link", f, backLinks

  if error then throw new Error "checkFace failed"



checkHorizon = (horizon) ->
  _.every _.map horizon, (h, i) ->
    next = horizon[(i + 1) % horizon.length]
    if h.b != next.a
      console.error "discontinuous horizon", h, next
      false
    else
      true

checkHull = (tracer, hull, points) ->
  valid = true
  _.each hull, (f) ->
    _.each points, (p) ->
      if visible face, point
        valid = false
        tracer.trace "OUTSIDE POINT",
          faces: [face]
          vertices: [point]

  valid



## The actual Quickhull solver

class QuickhullSolver
  constructor: (@tracer) ->
    @hull = []

  # find some sane initial points
  getInitialPoints: (points) ->
    getattr = (a) -> (p) -> p[a]

    pointsCopy = _.clone points

    # find extreme points in each dimension
    extremes = []
    removeFromPoints = (point) ->
      pointsCopy = _.without pointsCopy, point
      point

    extremes.push removeFromPoints(_.min pointsCopy, getattr 'x')
    extremes.push removeFromPoints(_.min pointsCopy, getattr 'y')
    extremes.push removeFromPoints(_.min pointsCopy, getattr 'z')
    extremes.push removeFromPoints(_.max pointsCopy, getattr 'x')
    extremes.push removeFromPoints(_.max pointsCopy, getattr 'y')
    extremes.push removeFromPoints(_.max pointsCopy, getattr 'z')

    cartesian = _.flatten(
      (_.map extremes, (p1) -> _.map extremes, (p2) -> [p1, p2]), true
    )

    # find point combination with greatest distance
    [m1, m2] = _.max cartesian, ([p1, p2]) ->
      p1.distanceTo p2

    # find point with greatest distance to those two points
    m3 = _.max extremes, (p3) ->
      q = p3.clone().sub(m1)
      q.cross(m2).length()

    [m1, m2, m3]

  #### get convex hull of faces
  getHull: (points) ->
    @tracer.trace "quickhull start",
      vertices: points
      subtitle: $('#instructions').html()

    [a, b, c] = @getInitialPoints points

    f = new Face a, b, c
    g = new Face a, c, b

    # assign points to initial hull hull
    assignPoints [f, g], points

    # connect initial faces to each other
    f.connect g, f.linkAB, g.linkCA
    f.connect g, f.linkBC, g.linkBC
    f.connect g, f.linkCA, g.linkAB

    # basic hull
    @hull = [f, g]

    if config.TRACE_INITIAL
      @tracer.trace "initial hull with normals",
        faces: @hull
        edges: _.map @hull, (f) -> f.normalLine()
        vertices: points
        hiVertices: [a, b, c]

    #@ sanity check
    @hull.forEach checkFace

    # recursive algorithm implemented with own stack
    stack = [g, f]
    while face = stack.shift()
      # skip faces that have been discarded
      if not face.deleted
        # try to expand the hull if face hasn't been deleted, add
        # newly created faces to work queue
        newFaces = @expandHull face
        stack.push newFaces...

    if checkHull @hull, points
      console.log "checkHull successful"

    @hull

  #### expand hull by creating new faces and removing old ones
  expandHull: (face) ->
    # if the face has no points assigned, leave everything unchanged
    if _.isEmpty face.assignedPoints
      return

    d = face.furthest.point

    # find horizon and list of visited faces
    {horizon, visited} = @getHorizon face, d

    if not checkHorizon horizon
      throw new Error "invalid horizon"

    if config.TRACE_HORIZON
      @tracer.trace "expand hull",
        faces: visited
        edges: horizon
        vertices: face.assignedPoints
        hiVertices: [d]
        subtitle: "#{visited.length} faces visible from furthest point"


    # Create new hull and reconnect faces properly. Because the horizon is
    # continuous, all faces will have proper orientation.
    newFaces = []
    prev = null
    horizon.forEach (link) =>
      link.horizon = false # reset
      {a, b} = link
      f = new Face a, b, d
      f.connect link.to, f.linkAB, link.inverse
      if prev
        prev.connect f, prev.linkBC, f.linkCA
      prev = f
      newFaces.push f

    prev.connect newFaces[0], prev.linkBC, newFaces[0].linkCA

    # re-assign points to newly created faces and delete visited faces
    visited.forEach (f) ->
      assignPoints newFaces, f.assignedPoints
      f.assignedPoints = []
      f.deleted = true

    if config.TRACE_NEW_FACE_EACH
      newFaces.forEach (f) ->
        @tracer.trace "new face",
          faces: [f]
          vertices: f.assignedPoints
          edges: [f.linkAB]
          hiVertices: [d]
          subtitle: """
            new face from found horizon edge to furthest point,
            #{f.assignedPoints.length} assigned points"""

    if config.TRACE_NEW_FACES
      @tracer.trace "new faces",
        vertices: [d]
        edges: horizon
        faces: newFaces
        subtitle: "#{newFaces.length} new faces along the found horizon"

    # add new faces to hull
    @hull.push newFaces...

    totalFaces = _.filter(@hull, (h) -> not h.deleted)

    @tracer.trace "new hull",
      faces: @hull
      hiFaces: newFaces
      vertices: points
      subtitle: "#{totalFaces.length} total hull faces"

    @hull.forEach checkFace

    newFaces

  #### Find boundary between visible and invisible faces
  # return as continuous list of FaceLinks creating a closed path
  getHorizon: (face, point) ->
    stack = [face]
    visited = []
    horizon = []

    # Because FaceLinks are not necessarily found in a continuous order,
    # maintain a list of paths and add newly found link to the start or end of
    # an existing path or create a new one.
    #
    # There probably is a better way to do this.
    mergePaths = (path, links) ->
      if path.length == 0
        path.push links...
        return true

      pathStart = _.first(path).a
      pathEnd = _.last(path).b

      linkStart = _.first(links).a
      linkEnd = _.last(links).b

      if linkStart == pathEnd
        path.push links...
      else if linkEnd == pathStart
        path.unshift links...
      else
        return false

      return true

    horizonPaths = []

    # if new link can't be merged with existing path, add new path
    addHorizon = (link) =>
      if not _.some(horizonPaths, (path) -> mergePaths path, [link])
        horizonPaths.push [link]

      if config.TRACE_HORIZON_STEP
        @tracer.trace "found horizon edge",
          faces: [link.from, link.to]
          edges: [link]
          vertices: [point]
          subtitle: 'boundary between visible and invisible face'

      # very rarely there are more than 2 paths to check
      if config.TRACE_MANY_HORIZON_PATHS
        if horizonPaths.length > 2
          horizonPaths.forEach (links, i) ->
            @tracer.trace "horizon path #{i}",
              faces: _.map links, (l) -> l.from
              edges: links

    # graph search starting form passed face
    while f = stack.pop()
      f.visited = true
      visited.push f

      f.links.forEach (l, i) =>
        l.horizon = not l.to.visibleBy(point)
        if l.horizon
          # if the face on the other side of the link is invisible, we have a
          # horizon link
          addHorizon l
        else
          # otherwise we might have a new face to expand the search to
          if not l.to.visited
            stack.push l.to
            l.to.visited = true


    # reset search state
    visited.forEach (f) -> f.visited = false


    # collapse horizon into single path
    # strictly speaking this is not guaranteed to terminate but it does
    horizon = []

    while p = horizonPaths.pop()
      mergePaths horizon, p

    # return horizon and list of visited faces
    {horizon, visited}

# end of core quickhull algorithm

## Put everything together

#### create random points
makePoints = (random, n) ->
  s = 200.0
  points = []

  for [0..n]
    vector = new THREE.Vector3(
      random.gauss(), random.gauss(), random.gauss()
    ) until vector?.length() < 3
    points.push vector.multiplyScalar(s)

  points

#### handy method to debug certain cases
seed = null
#@ seed = 726

if seed == null
  seed = (Math.random() * 10000).toFixed 0

console.log "seed", seed
random = new Random
random.seed seed

window.points = makePoints random, 1000

animate()

reset = (seed) ->
  if seed then random.seed seed
  window.points = makePoints random, 100
  if window.tracer
    window.tracer.clear()
  window.tracer = new Tracer
  window.solver = new QuickhullSolver window.tracer
  window.solver.getHull window.points

#### Settings widget


$settings = $("#settings")

addSetting = (description, key) ->
  changeKey = (key, value) ->
    config[key] = value
    reset seed

  $checkbox = $("<input>", type: "checkbox")
    .on('change', (e) -> changeKey key, $checkbox.prop 'checked')
  $checkbox.prop 'checked', config[key]
  $el = $("<div>").append $("<label>").text(description).append($checkbox)
  $settings.append $el

addSetting 'show initial points',       "TRACE_INITIAL"
addSetting 'show new horizon',          "TRACE_HORIZON"
addSetting 'show horizon search step',  "TRACE_HORIZON_STEP"
addSetting 'show new individual faces', "TRACE_NEW_FACE_EACH"
addSetting 'show new face group',       "TRACE_NEW_FACES"


#### respond to user input

lastKey = null
onKeyDown = (e) ->
  #@ console.log e.keyCode
  KEY_LEFT = 37
  KEY_RIGHT = 39
  KEY_J = "J".charCodeAt 0
  KEY_K = "K".charCodeAt 0
  KEY_R = "R".charCodeAt 0
  KEY_G = "G".charCodeAt 0
  KEY_END = 35
  KEY_START = 36

  KEYS_PREV = [KEY_LEFT, KEY_K]
  KEYS_NEXT = [KEY_RIGHT, KEY_J]

  KEYS_END = [KEY_END]
  KEYS_START = [KEY_START]

  KEYS_RESET = [KEY_R]

  if _.contains(KEYS_PREV, e.keyCode) then tracer.showPrev()
  if _.contains(KEYS_NEXT, e.keyCode) then tracer.showNext()
  if _.contains(KEYS_START, e.keyCode) then tracer.showFirst()
  if _.contains(KEYS_END, e.keyCode) then tracer.showLast()
  if _.contains(KEYS_RESET, e.keyCode) then reset()

  if (e.keyCode == KEY_G)
    if e.shiftKey
      tracer.showLast()
    else
      tracer.showFirst()

  lastKey = e

onMouseWheel = (e) ->
  #@ console.log e
  if e.originalEvent.wheelDeltaY < 0 then tracer.showNext()
  if e.originalEvent.wheelDeltaY > 0 then tracer.showPrev()

$(window).on 'keydown', onKeyDown
$(window).on 'mousewheel', onMouseWheel

#### get it started
reset()
