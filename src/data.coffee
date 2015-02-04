fs = require('fs')
topojson = require('topojson')


module.exports = ->
  bboxCiucas = [25.8449, 45.4371, 26.0518, 45.5619]
  obj = {}
  relationIds = []
  wayIds = []
  for o in JSON.parse(fs.readFileSync('data/ciucas.json')).elements
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

  map = {
    topo: topojson.topology(layers, quantization: 1000000)
    bbox: bboxCiucas
    routes: route(obj[id]) for id in relationIds
  }

  fs.writeFileSync('build/ciucas.json', JSON.stringify(map))
