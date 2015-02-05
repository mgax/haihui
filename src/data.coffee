fs = require('fs')
request = require('request')
topojson = require('topojson')


query = (bbox) ->
  filters = [
    {t: 'relation', k: 'route',   v: 'hiking'}
  ]
  overpassBbox = [bbox[1], bbox[0], bbox[3], bbox[2]]
  item = (f) -> "#{f.t}[\"#{f.k}\"=\"#{f.v}\"](#{overpassBbox});"
  items = (item(f) for f in filters).join('')
  return "[out:json][timeout:25];(#{items});out body;>;out skel qt;"


module.exports = ->
  bboxCiucas = [25.845, 45.437, 26.043, 45.562]
  q = query(bboxCiucas)
  url = "http://overpass-api.de/api/interpreter?data=#{encodeURIComponent(q)}"
  request url, (err, res, body) ->
    map = compile(bboxCiucas, JSON.parse(body))
    fs.writeFileSync('build/ciucas.json', JSON.stringify(map))


compile = (bbox, osm) ->
  obj = {}
  relationIds = []
  wayIds = []
  for o in osm.elements
    obj[o.id] = o
    if o.type == 'relation'
      relationIds.push o.id
    if o.type == 'way'
      wayIds.push o.id


  pos = (id) -> node = obj[id]; return [node.lon, node.lat]

  segment = (id) -> way = obj[id]; return {
    type: 'Feature'
    id: id
    geometry:
      type: 'LineString'
      coordinates: pos(n) for n in way.nodes
  }

  layer = (features) -> {type: 'FeatureCollection', features: features}

  route = (relation) ->
    segments = []
    for m in relation.members
      if obj[m.ref].type == 'way'
        segments.push(m.ref)

    return {
      segments: segments
      symbol: relation.tags['osmc:symbol']
    }

  layers = {
    segments: layer(segment(id) for id in wayIds)
  }

  return {
    topo: topojson.topology(layers, quantization: 1000000)
    bbox: bbox
    routes: route(obj[id]) for id in relationIds
  }
