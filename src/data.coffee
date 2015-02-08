child_process = require('child_process')
d3 = require('d3')
fs = require('fs')
request = require('request')
topojson = require('topojson')
turf = require('turf')
Q = require('q')


REGION = {
  ciucas: [25.845, 45.437, 26.043, 45.562]
  fagaras: [24.30, 45.47, 24.89, 45.73]
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
    {t: 'relation', k: 'route',   v: 'hiking'}
    {t: 'node',     k: 'natural', v: 'saddle'}
    {t: 'node',     k: 'natural', v: 'peak'}
    {t: 'node',     k: 'tourism', v: 'chalet'}
    {t: 'way',      k: 'tourism', v: 'chalet'}
    {t: 'node',     k: 'tourism', v: 'alpine_hut'}
    {t: 'way',      k: 'tourism', v: 'alpine_hut'}
  ]
  overpassBbox = [bbox[1], bbox[0], bbox[3], bbox[2]]
  item = (f) -> "#{f.t}[\"#{f.k}\"=\"#{f.v}\"](#{overpassBbox});"
  items = (item(f) for f in filters).join('')
  return "[out:json][timeout:25];(#{items});out body;>;out skel qt;"


data = module.exports = {}

data.buildAll = ->
  def = Q()

  Object.keys(REGION).sort().forEach (region) ->
    def = def.then ->
      data.build(region)

  return def

data.build = (region) ->
  console.log("building", region)
  deferred = Q.defer()

  data.dem(region)

  .then ->
    bbox = REGION[region]
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

    if o.tags.tourism == 'chalet' or o.tags.tourism == 'alpine_hut'
      if o.type == 'node' or o.type == 'way'
        poi.push(tourism(o))

  layers = {
    segments: turf.featurecollection(segment(id) for id in segmentIds.values())
    poi: turf.featurecollection(poi)
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
  bbox = REGION[region]

  exec("gdalwarp
        data/srtm-1arcsec-ro.tiff
        data/srtm-1arcsec-#{region}.tiff
        -te #{bbox.join(' ')}")
  .then ->
    exec("gdal_contour
          data/srtm-1arcsec-#{region}.tiff
          data/contours/#{region}.shp
          -i 100")
  .then ->
    exec("topojson
          contour=data/contours/#{region}.shp
          -o data/contours/#{region}.topojson
          -s .00000000001")
  .done ->
    demDone.resolve()

  return demDone.promise
