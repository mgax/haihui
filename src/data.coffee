child_process = require('child_process')
d3 = require('d3')
fs = require('fs')
request = require('request')
topojson = require('topojson')
turf = require('turf')
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


query = (bbox) ->
  filters = [
    'relation["route"="hiking"]'
    'node["natural"="saddle"]'
    'node["natural"="peak"]'
    'node["amenity"="shelter"]["shelter_type"="basic_hut"]'
    'way["highway"~""]'
    'way["waterway"~""]'
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

  .then ->
    bbox = data.REGION[region].bbox
    q = query(bbox)
    url = "http://overpass-api.de/api/interpreter?data=#{encodeURIComponent(q)}"
    console.log("overpass:", q)

    request url, (err, res, body) ->
      dem = JSON.parse(fs.readFileSync("data/contours/#{region}.topojson"))
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

  pos = (id) ->
    node = obj[id]
    return [node.lon, node.lat]

  segment = (id) ->
    f = turf.linestring(pos(n) for n in obj[id].nodes)
    f.id = id
    return f

  natural = (node) ->
    f = turf.point([node.lon, node.lat])
    f.id = node.id
    f.properties = {
      name: node.tags.name
      type: node.tags.natural
    }
    return f

  tourism = (obj) ->
    switch obj.type
      when 'node'
        f = turf.point([obj.lon, obj.lat])
      when 'way'
        f = turf.centroid(segment(obj.id))
    f.id = obj.id
    f.properties = {
      name: obj.tags.name
      type: obj.tags.tourism
    }
    return f

  shelter = (obj) ->
    f = turf.point([obj.lon, obj.lat])
    f.id = obj.id
    f.properties = {
      name: obj.tags.name
      type: 'basic_hut'
    }
    return f

  highway = (obj) ->
    f = turf.linestring(pos(n) for n in obj.nodes)
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
    turf.linestring(pos(n) for n in obj.nodes)

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

  layers = {
    segments: turf.featurecollection(segment(id) for id in segmentIds.values())
    poi: turf.featurecollection(poi)
    highways: turf.featurecollection(highways)
    rivers: turf.featurecollection(rivers)
  }

  return {
    topo: topojson.topology(layers, {
      quantization: 1000000
      'property-transform': (f) -> f.properties
    })
    dem: dem
    bbox: bbox
    routes: route(obj[id]) for id in routeIds.values()
  }


data.dem = (region) ->
  demDone = Q.defer()
  bbox = data.REGION[region].bbox

  exec("rm -f data/contours/#{region}.*")
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
    exec("topojson
          contour=data/contours/#{region}.shp
          -o data/contours/#{region}.topojson
          --id-property ID
          -p elevation
          -s .00000000001")
  .done ->
    demDone.resolve()

  return demDone.promise


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

  fs.writeFileSync("build/turfbits.js", fs.readFileSync("turfbits.js"))
  fs.writeFileSync("build/screenshot.jpg", fs.readFileSync("screenshot.jpg"))
