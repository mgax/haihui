d3 = require('d3')
fs = require('fs')
request = require('request')
topojson = require('topojson')
turf = require('turf')
Q = require('q')


query = (bbox) ->
  filters = [
    {t: 'relation', k: 'route',   v: 'hiking'}
    {t: 'node',     k: 'natural', v: 'saddle'}
    {t: 'node',     k: 'natural', v: 'peak'}
    {t: 'node',     k: 'tourism', v: 'chalet'}
    {t: 'way',      k: 'tourism', v: 'chalet'}
  ]
  overpassBbox = [bbox[1], bbox[0], bbox[3], bbox[2]]
  item = (f) -> "#{f.t}[\"#{f.k}\"=\"#{f.v}\"](#{overpassBbox});"
  items = (item(f) for f in filters).join('')
  return "[out:json][timeout:25];(#{items});out body;>;out skel qt;"


module.exports = ->
  deferred = Q.defer()
  bboxCiucas = [25.845, 45.437, 26.043, 45.562]
  q = query(bboxCiucas)
  url = "http://overpass-api.de/api/interpreter?data=#{encodeURIComponent(q)}"
  request url, (err, res, body) ->
    map = compile(bboxCiucas, JSON.parse(body))
    fs.writeFileSync('build/ciucas.json', JSON.stringify(map))
    deferred.resolve()

  return deferred.promise


compile = (bbox, osm) ->
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
    if o.type == 'relation' and o.tags.route == 'hiking'
      routeIds.add(o.id)
      for m in o.members
        if m.type == 'way'
          segmentIds.add(m.ref)

    if o.type == 'node' and o.tags? and o.tags.natural?
      poi.push(natural(o))

    if o.tags? and o.tags.tourism == 'chalet'
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
    bbox: bbox
    routes: route(obj[id]) for id in routeIds.values()
  }
