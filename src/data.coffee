fs = require('fs')
topojson = require('topojson')


module.exports = ->
  bboxCiucas = [25.8449, 45.4371, 26.0518, 45.5619]
  obj = {}
  routeIds = []
  wayIds = []
  for o in JSON.parse(fs.readFileSync('data/ciucas.json')).elements
    obj[o.id] = o
    if o.type == 'relation'
      routeIds.push o.id
    if o.type == 'way'
      wayIds.push o.id


  pos = (id) -> node = obj[id]; return [node.lon, node.lat]

  segment = (id) -> way = obj[id]; return {
    type: 'Feature'
    properties:
      id: id
    geometry:
      type: 'LineString'
      coordinates: pos(n) for n in way.nodes
  }

  layer = (features) -> {type: 'FeatureCollection', features: features}

  layers = {
    segments: layer(segment(id) for id in wayIds)
  }

  map = topojson.topology(layers, quantization: 1000000)
  map.bbox = bboxCiucas

  fs.writeFileSync('build/ciucas.topojson', JSON.stringify(map))
