child_process = require('child_process')
d3 = require('d3')
fs = require('fs')
request = require('request')
topojson = require('topojson')
turf = require('turf')
proj4 = require('proj4')
Q = require('q')

data = module.exports = {}


data.REGION = {
  bucegi:  {bbox: [25.39, 45.34, 25.54, 45.49], title: "Bucegi"}
  ceahlau: {bbox: [25.85, 46.84, 26.08, 47.04], title: "Ceahlău"}
  ciucas:  {bbox: [25.84, 45.43, 26.05, 45.56], title: "Ciucaș"}
  crai:    {bbox: [25.17, 45.49, 25.29, 45.57], title: "Piatra Craiului"}
  fagaras: {bbox: [24.30, 45.47, 24.89, 45.73], title: "Făgăraș"}
  iezer:   {bbox: [24.85, 45.38, 25.10, 45.55], title: "Iezer"}
  macin:   {bbox: [28.13, 45.07, 28.42, 45.29], title: "Măcin"}
  parang:  {bbox: [23.43, 45.31, 23.82, 45.41], title: "Parâng"}
  retezat: {bbox: [22.72, 45.29, 23.00, 45.42], title: "Retezat"}
}

SLEEPING_PLACE = {
  'chalet': true
  'alpine_hut': true
  'hotel': true
}


exec = (cmd) ->
  done = Q.defer()
  console.log cmd
  child_process.exec cmd, done.resolve
  return done.promise


ensureDir = (path) ->
  fs.mkdirSync(path) unless fs.existsSync(path)


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
  ]
  overpassBbox = [bbox[1], bbox[0], bbox[3], bbox[2]]
  item = (f) -> "#{f}(#{overpassBbox});"
  items = (item(f) for f in filters).join('')
  return "[out:json][timeout:25];(#{items});out body;>;out skel qt;"


data.build = (region) ->
  console.log("building", region)
  deferred = Q.defer()

  data.dem(region)

  .then (dem) ->
    bbox = data.REGION[region].bbox
    q = query(bbox)
    url = "http://overpass-api.de/api/interpreter?data=#{encodeURIComponent(q)}"
    console.log("overpass:", q)

    request url, (err, res, body) ->
      p = JSON.parse(body)
      db = compileOsm(bbox, p, dem)
      ensureDir("build/#{region}")
      fs.writeFileSync("build/#{region}/data.json", JSON.stringify(db))
      console.log("done", region)
      deferred.resolve()

  return deferred.promise


compileOsm = (bbox, osm, dem) ->
  obj = {}
  routeIds = d3.set()
  segmentIds = d3.set()
  poi = []
  highways = []
  rivers = []
  lakes = []

  projParams = albersProj(albers(bbox))
  projection = proj4(projParams)

  project = (coord) -> [x, y] = projection.forward(coord); [+x, +y]

  projectNode = (node) -> project([node.lon, node.lat])

  point = (node) -> turf.point(projectNode(node))

  linestring = (nodes) -> turf.linestring(projectNode(obj[n]) for n in nodes)

  polygon = (nodes) -> turf.polygon([projectNode(obj[n]) for n in nodes])

  segment = (id) ->
    f = linestring(obj[id].nodes)
    f.id = id
    return f

  natural = (node) ->
    f = point(node)
    f.id = node.id
    f.properties = {
      name: node.tags.name
      type: node.tags.natural
    }
    return f

  tourism = (obj) ->
    switch obj.type
      when 'node'
        f = point(obj)
      when 'way'
        f = turf.centroid(segment(obj.id))
    f.id = obj.id
    f.properties = {
      name: obj.tags.name
      type: obj.tags.tourism
    }
    return f

  shelter = (obj) ->
    f = point(obj)
    f.id = obj.id
    f.properties = {
      name: obj.tags.name
      type: 'basic_hut'
    }
    return f

  highway = (obj) ->
    f = linestring(obj.nodes)
    grade = switch obj.tags.highway
      when 'track' then 'path'
      when 'path' then 'path'
      when 'footway' then 'path'
      when 'residential' then null
      when 'living_street' then null
      else 'road'
    return unless grade?
    f.properties = {grade: grade}
    return f

  river = (obj) ->
    linestring(obj.nodes)

  lake = (obj) ->
    f = polygon(obj.nodes)
    f.properties = {name: obj.tags.name}
    return f

  route = (relation) ->
    segments = []
    for m in relation.members
      if obj[m.ref].type == 'way'
        segments.push(m.ref)

    return {
      segments: segments
      symbol: relation.tags['osmc:symbol']
    }

  for o in osm.elements
    obj[o.id] = o

  for o in osm.elements
    continue unless o.tags?

    if o.type == 'relation' and o.tags.route == 'hiking'
      routeIds.add(o.id)
      for m in o.members
        if m.type == 'way'
          segmentIds.add(m.ref)

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

  layers = {
    segments: turf.featurecollection(segment(id) for id in segmentIds.values())
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
    dem: dem
    routes: route(obj[id]) for id in routeIds.values()
    bbox: [].concat(project(bbox.slice(0, 2)), project(bbox.slice(2, 4)))
    projParams: projParams
  }


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


data.html = ->
  Handlebars = require('handlebars')
  template = (name) ->
    Handlebars.compile(fs.readFileSync("templates/#{name}", encoding: 'utf-8'))

  index_html = template('index.html')
  index_appcache = template('index.appcache')
  region_html = template('region.html')
  region_appcache = template('region.appcache')

  timestamp = (new Date()).toJSON()
  regions = Object.keys(data.REGION).sort()
  for region in regions
    ensureDir("build/#{region}")
    fs.writeFileSync(
      "build/#{region}/index.html",
      region_html(title: data.REGION[region].title)
    )
    region_manifest = region_appcache(timestamp: timestamp)
    fs.writeFileSync("build/#{region}/manifest.appcache", region_manifest)

  regionList = ({slug: r, title: data.REGION[r].title} for r in regions)
  fs.writeFileSync("build/index.html", index_html(regionList: regionList))
  index_manifest = index_appcache(timestamp: timestamp)
  fs.writeFileSync("build/manifest.appcache", index_manifest)

  fs.writeFileSync("build/screenshot.jpg", fs.readFileSync("screenshot.jpg"))


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
