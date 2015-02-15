app.index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


app.inside = (pos, bbox) ->
  bbox[0] <= pos[0] and pos[0] < bbox[2] and bbox[1] <= pos[1] and pos[1] < bbox[3]


app.segmentLength = (segment, save=false) ->
  points = segment.geometry.coordinates
  sum = 0
  prev = points[0]
  if save then prev.push(sum)

  for point in points.slice(1)
    dx = point[0] - prev[0]
    dy = point[1] - prev[1]
    delta = Math.sqrt(dx*dx + dy*dy)
    if save then point.push(sum += delta)
    prev = point

  if save then segment.properties.length = sum
  return sum


app.along = (segment, distance) ->
  points = segment.geometry.coordinates
  prev = points[0]
  for point in points.slice(1)
    if point[3] >= distance
      f = (distance - prev[3]) / (point[3] - prev[3])
      dx = point[0] - prev[0]
      dy = point[1] - prev[1]
      target = [prev[0] + dx * f, prev[1] + dy * f]
      return {
        geometry: {
          type: 'Point'
          coordinates: target
        }
      }


