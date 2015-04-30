child_process = require('child_process')
d3 = require('d3')
fs = require('fs')
request = require('request')
topojson = require('topojson')
turf = require('turf')
proj4 = require('proj4')
osmtogeojson = require('osmtogeojson')
crypto = require('crypto')
Q = require('q')
Handlebars = require('handlebars')

data = module.exports = {}


data.REGION = {
  bucegi:     {bbox: [25.39, 45.34, 25.54, 45.49], title: "Bucegi"}
  capatanii:  {bbox: [24.00, 45.17, 24.19, 45.34], title: "Căpățânii"}
  ceahlau:    {bbox: [25.85, 46.84, 26.08, 47.04], title: "Ceahlău"}
  ciucas:     {bbox: [25.84, 45.43, 26.05, 45.56], title: "Ciucaș"}
  crai:       {bbox: [25.17, 45.49, 25.29, 45.57], title: "Piatra Craiului"}
  fagaras:    {bbox: [24.30, 45.47, 24.89, 45.73], title: "Făgăraș"}
  iezer:      {bbox: [24.85, 45.38, 25.10, 45.55], title: "Iezer"}
  macin:      {bbox: [28.13, 45.07, 28.42, 45.29], title: "Măcin"}
  parang:     {bbox: [23.43, 45.31, 23.82, 45.41], title: "Parâng"}
  piatramare: {bbox: [25.59, 45.48, 25.75, 45.60], title: "Piatra Mare"}
  retezat:    {bbox: [22.72, 45.29, 23.00, 45.42], title: "Retezat"}
}

SLEEPING_PLACE = {
  'chalet': true
  'alpine_hut': true
  'hotel': true
}

MAXBUFFER = 1024 * 1024 * 64  # 64MB
SAVERAW = process.env.SAVERAW
RETRY = +(process.env.RETRY or 0)


osmid = (o) -> "#{o.type}/#{o.id}"


template = (name) ->
  Handlebars.compile(fs.readFileSync("templates/#{name}", encoding: 'utf-8'))


exec = (cmd, stdin='') ->
  done = Q.defer()
  console.log cmd
  exec_cb = (err, data) ->
    if err?
      done.reject(err)
    else
      done.resolve(data)
  child = child_process.exec(cmd, maxBuffer: MAXBUFFER, exec_cb)
  child.stdin.end(stdin)
  return done.promise


execSync = (cmd, stdin='') ->
  child_process.execSync(cmd, input: stdin, maxBuffer: MAXBUFFER)


httpGet = (url) ->
  deferred = Q.defer()
  request url, (err, res, body) ->
    if err?
      deferred.reject(err)
    else
      deferred.resolve(body)
  return deferred.promise


ensureDir = (path) ->
  fs.mkdirSync(path) unless fs.existsSync(path)


retry = (n, fn, args...) ->
  fn(args...)
  .catch (e) ->
    if n > 0
      console.log "call failed, trying #{n} more times"
      retry(n-1, fn, args...)


closeRings = (feature) ->
  closeRing = (ring) ->
    first = ring[0]
    last = ring[ring.length-1]
    unless first[0] == last[0] and first[1] == last[1]
      console.log "Closing ring at #{first}"
      ring.push(first)

  if feature.geometry.type == 'Polygon'
    feature.geometry.coordinates.forEach(closeRing)


buffer = (geometry) ->
  JSON.parse(execSync('python src/buffer.py', JSON.stringify(geometry)))


albers = (bbox) ->
  round = (v) -> d3.round(v, 4)
  dp = (bbox[3] - bbox[1]) / 6
  return {
    lat_1: round(bbox[3] + dp)
    lat_2: round(bbox[1] - dp)
    lat_0: round((bbox[1] + bbox[3]) / 2)
    lon_0: round((bbox[0] + bbox[2]) / 2)
  }


albersProj = (param) ->
  return "+proj=aea +x0=0 +y0=0 +units=m +no_defs
          +lat_1=#{param.lat_1} +lat_2=#{param.lat_2}
          +lat_0=#{param.lat_0} +lon_0=#{param.lon_0}"


landuseType = (o) ->
  switch o.tags.natural
    when 'beach'        then return 'beach'
    when 'heath'        then return 'heath'
    when 'rock'         then return 'rock'
    when 'scrub'        then return 'scrub'
    when 'wood'         then return 'forest'
    when 'wetland'
      switch o.tags.wetland
        when 'marsh'    then return 'marsh'

  switch o.tags.landuse
    when 'farmland'     then return 'farmland'
    when 'forest'       then return 'forest'
    when 'grass'        then return 'grass'
    when 'industrial'   then return 'industrial'
    when 'meadow'       then return 'meadow'
    when 'orchard'      then return 'orchard'
    when 'quarry'       then return 'quarry'
    when 'residential'  then return 'residential'
    when 'vineyard'     then return 'vineyard'

  switch o.tags.leisure
    when 'park'         then return 'park'


query = (bbox) ->
  filters = [
    'relation["route"="hiking"]'
    'node["natural"="saddle"]'
    'node["natural"="peak"]'
    'node["amenity"="shelter"]["shelter_type"="basic_hut"]'
    'way["highway"~""]'
    'way["waterway"~""]'
    'way["water"="lake"]'
    'way["water"="reservoir"]'
    'node["tourism"~""]'
    'way["tourism"~""]'
    'way["landuse"~""]'
    'relation["landuse"~""]'
    'way["natural"~""]'
    'relation["natural"~""]'
    'way["leisure"="park"]'
    'relation["leisure"="park"]'
  ]
  overpassBbox = [bbox[1], bbox[0], bbox[3], bbox[2]]
  item = (f) -> "#{f}(#{overpassBbox});"
  items = (item(f) for f in filters).join('')
  return "[out:json][timeout:25];(#{items});out meta;>;out skel qt;"


data.build = (region) ->
  console.log("=====    building '#{region}'    =====")
  bbox = data.REGION[region].bbox
  dem = null

  data.dem(region)

  .then (rv) ->
    dem = rv
    q = query(bbox)
    url = "http://overpass-api.de/api/interpreter?data=#{encodeURIComponent(q)}"
    console.log("overpass:", q)
    retry(RETRY, httpGet, url)

  .then (resp) ->
    if SAVERAW?
      return exec('python -m json.tool', resp).then (prettyResp) ->
        fs.writeFileSync("#{SAVERAW}/#{region}.json", prettyResp)
        return resp

    else
      return resp

  .then (resp) ->
    p = JSON.parse(resp)
    compileOsm(bbox, p, dem)

  .then (db) ->
    ensureDir("build/#{region}")
    fs.writeFileSync("build/#{region}/data.json", JSON.stringify(db))
    data.htmlRegion(region)
    console.log("done", region)


compileOsm = (bbox, osm, dem) ->
  obj = {}
  routeIds = d3.set()
  segmentIds = d3.set()
  poi = []
  highways = []
  rivers = []
  lakes = []
  land = []

  projParams = albersProj(albers(bbox))
  projection = proj4(projParams)

  project = (coord) -> [x, y] = projection.forward(coord); [+x, +y]

  projectNode = (node) -> project([node.lon, node.lat])

  point = (node) -> turf.point(projectNode(node))

  linestring = (nodes) -> turf.linestring(projectNode(obj["node/#{n}"]) for n in nodes)

  polygon = (nodes) -> turf.polygon([projectNode(obj["node/#{n}"]) for n in nodes])

  bboxPoly = turf.polygon([[
    [bbox[0], bbox[1]]
    [bbox[0], bbox[3]]
    [bbox[2], bbox[3]]
    [bbox[2], bbox[1]]
    [bbox[0], bbox[1]]
  ]])

  projectCoord = (coord) ->
    if typeof(coord[0]) == 'number'
      [coord[0], coord[1]] = project(coord)
    else
      coord.map(projectCoord)

  osmFeature = {}
  osmtogeojson(osm).features.forEach (feature) ->
    osmFeature[feature.id] = feature

  segment = (id) ->
    f = linestring(obj[id].nodes)
    f.id = id
    return f

  natural = (node) ->
    f = point(node)
    f.id = osmid(node)
    f.properties = {
      name: node.tags.name
      type: node.tags.natural
    }
    return f

  tourism = (o) ->
    switch o.type
      when 'node'
        f = point(o)
      when 'way'
        f = turf.centroid(segment(osmid(o)))
    f.id = osmid(o)
    f.properties = {
      name: o.tags.name
      type: o.tags.tourism
    }
    return f

  shelter = (o) ->
    f = point(o)
    f.id = osmid(o)
    f.properties = {
      name: o.tags.name
      type: 'basic_hut'
    }
    return f

  highway = (o) ->
    f = linestring(o.nodes)
    f.id = osmid(o)
    grade = switch o.tags.highway
      when 'track' then 'path'
      when 'path' then 'path'
      when 'footway' then 'path'
      when 'residential' then null
      when 'living_street' then null
      else 'road'
    return unless grade?
    f.properties = {grade: grade}
    return f

  river = (o) ->
    f = linestring(o.nodes)
    f.id = osmid(o)
    return f

  lake = (o) ->
    f = polygon(o.nodes)
    f.id = osmid(o)
    f.properties = {name: o.tags.name}
    return f

  landFeature = (o) ->
    type = landuseType(o)
    f = osmFeature[osmid(o)]
    closeRings(f)
    try
      f = turf.intersect(bboxPoly, f)
    catch e
      console.log "#{f.id} error during intersection (#{e}), buffering"
      f.geometry = buffer(f.geometry)
      f = turf.intersect(bboxPoly, f)
    projectCoord(f.geometry.coordinates)
    f.id = osmid(o)
    f.properties = {type: type}
    return f

  route = (relation) ->
    segments = []
    for m in relation.members
      id = "#{m.type}/#{m.ref}"
      if obj[id].type == 'way'
        segments.push(id)

    return {
      segments: segments
      symbol: relation.tags['osmc:symbol']
    }

  for o in osm.elements
    obj[osmid(o)] = o

  for o in osm.elements
    continue unless o.tags?

    if o.type == 'relation' and o.tags.route == 'hiking'
      routeIds.add(osmid(o))
      for m in o.members
        if m.type == 'way'
          segmentIds.add("way/#{m.ref}")

    if o.type == 'node' and o.tags.natural?
      poi.push(natural(o))

    if SLEEPING_PLACE[o.tags.tourism]
      if o.type == 'node' or o.type == 'way'
        poi.push(tourism(o))

    if o.type == 'node' and o.tags.amenity == 'shelter' and o.tags.shelter_type == 'basic_hut'
      poi.push(shelter(o))

    if o.type == 'way' and o.tags.highway?
      r = highway(o)
      if r? then highways.push(r)

    if o.type == 'way' and o.tags.waterway?
      rivers.push(river(o))

    if o.type == 'way' and (o.tags.water == 'lake' or o.tags.water == 'reservoir')
      lakes.push(lake(o))

    if o.type == 'way' or o.type == 'relation'
      if landuseType(o)?
        land.push(landFeature(o))

  altitudeList(poi.map((p) -> projection.inverse(p.geometry.coordinates)))

  .then (rv) ->
    rv.forEach (altitude, n) ->
      poi[n].properties.altitude = altitude

    poi.sort((a, b) -> a.properties.altitude - b.properties.altitude)

    layers = {
      segments: turf.featurecollection(segment(id) for id in segmentIds.values().sort())
      poi: turf.featurecollection(poi)
      highways: turf.featurecollection(highways)
      rivers: turf.featurecollection(rivers)
      lakes: turf.featurecollection(lakes)
    }

    return {
      topo: topojson.topology(layers, {
        quantization: 1000000
        'property-transform': (f) -> f.properties
      })
      land: topojson.simplify(topojson.topology({land: turf.featurecollection(land)}, {
        quantization: 1000000
        'property-transform': (f) -> f.properties
      }), 'minimum-area': 200, 'coordinate-system': 'cartesian')
      dem: dem
      routes: route(obj[id]) for id in routeIds.values()
      bbox: [].concat(project(bbox.slice(0, 2)), project(bbox.slice(2, 4)))
      projParams: projParams
    }


altitudeList = (coordinateList) ->
  input = coordinateList.map((p) -> "#{p[0]} #{p[1]}\n").join('')

  exec("gdallocationinfo -wgs84 -valonly data/srtm-1arcsec-ro.tiff", input)

  .then (out) ->
    return out.trim().split("\n").map((line) -> +line)


data.dem = (region) ->
  bbox = data.REGION[region].bbox
  demPath = "data/contours/#{region}.topojson"

  buildDem = ->
    demDone = Q.defer()
    exec("rm -f data/contours/#{region}.*")
    exec("rm -f data/contours/#{region}-prj.*")
    .then ->
      exec("gdalwarp
            data/srtm-1arcsec-ro.tiff
            data/contours/#{region}.tiff
            -te #{bbox.join(' ')}")
    .then ->
      exec("gdal_contour
            data/contours/#{region}.tiff
            data/contours/#{region}.shp
            -a elevation
            -i 100")
    .then ->
      exec("ogr2ogr
            -t_srs '#{albersProj(albers(bbox))}'
            data/contours/#{region}-prj.shp
            data/contours/#{region}.shp")
    .then ->
      exec("topojson
            contour=data/contours/#{region}-prj.shp
            -o #{demPath}
            --id-property ID
            -p elevation
            -s 500")
    .done ->
      dem = JSON.parse(fs.readFileSync(demPath))
      dem.wgsBbox = bbox
      fs.writeFileSync(demPath, JSON.stringify(dem))
      demDone.resolve(dem)

    return demDone.promise

  if fs.existsSync(demPath)
    dem = JSON.parse(fs.readFileSync(demPath))
    if JSON.stringify(bbox) == JSON.stringify(dem.wgsBbox)
      console.log "using cached dem topojson"
      return Q(dem)

  return buildDem()


htmlManifest = (directory, fileNameList) ->
  manifest_appcache = template('manifest.appcache')

  checksum = (filePath) ->
    hash = crypto.createHash('sha1')
    if /\/$/.test(filePath)
      filePath += 'index.html'
    hash.update(fs.readFileSync(filePath))
    return hash.digest('hex')

  fileList = fileNameList.map (name) -> {
    name: name
    checksum: checksum("#{directory}/#{name}")
  }
  return manifest_appcache(fileList: fileList)


data.htmlGlobal = ->
  index_html = template('index.html')

  regions = Object.keys(data.REGION).sort()
  regionList = ({slug: r, title: data.REGION[r].title} for r in regions)
  fs.writeFileSync("build/index.html", index_html(regionList: regionList))
  fs.writeFileSync("build/screenshot.jpg", fs.readFileSync("screenshot.jpg"))
  index_manifest = htmlManifest("build", [
    './'
    './screenshot.jpg'
    './bootstrap.min.css'
  ])
  fs.writeFileSync("build/manifest.appcache", index_manifest)


data.htmlRegion = (region) ->
  region_html = template('region.html')

  ensureDir("build/#{region}")
  fs.writeFileSync(
    "build/#{region}/index.html",
    region_html(title: data.REGION[region].title)
  )
  region_manifest = htmlManifest("build/#{region}", [
    './'
    '../region.css'
    '../d3.min.js'
    '../topojson.min.js'
    '../proj4.js'
    '../ui.js'
    './data.json'
  ])
  fs.writeFileSync("build/#{region}/manifest.appcache", region_manifest)


data.html = ->
  data.htmlGlobal()
  for region in Object.keys(data.REGION).sort()
    data.htmlRegion(region)


projectionError = (def, bbox, lng, lat) ->
  projection = proj4(def)
  proj = (p) -> [x, y] = projection.forward(p); [+x, +y]
  dist = (a, b) -> Math.sqrt((a[0]-b[0])*(a[0]-b[0]) + (a[1]-b[1])*(a[1]-b[1]))
  turfdist = (ta, tb) -> turf.distance(ta, tb, 'kilometers') * 1000

  err = (p1, p2) ->
    1 - dist(proj(p1), proj(p2)) / turfdist(turf.point(p1), turf.point(p2))

  return [
    d3.round(err([lng, lat], [lng + .00001, lat]), 6)
    d3.round(err([lng, lat], [lng, lat + .00001]), 6)
  ]


data.err = (region) ->
  bbox = data.REGION[region].bbox
  errors = (def) ->
    console.log projectionError(def, bbox, bbox[0], bbox[1])
    console.log projectionError(def, bbox, bbox[2], bbox[3])
    console.log projectionError(def, bbox, bbox[2], bbox[1])
    console.log projectionError(def, bbox, bbox[0], bbox[3])
    console.log projectionError(def, bbox, (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)
    console.log projectionError(def, bbox, bbox[0], (bbox[1] + bbox[3]) / 2)
    console.log projectionError(def, bbox, bbox[2], (bbox[1] + bbox[3]) / 2)
    console.log projectionError(def, bbox, (bbox[0] + bbox[2]) / 2, bbox[1])
    console.log projectionError(def, bbox, (bbox[0] + bbox[2]) / 2, bbox[3])
  console.log 'albers'
  errors(albersProj(albers(bbox)))
  console.log 'stereo70'
  errors('+proj=sterea +lat_0=46 +lon_0=25 +k=0.99975 +x_0=500000 +y_0=500000 +ellps=krass +units=m +no_defs')
