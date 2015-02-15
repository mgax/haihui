app.index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


app.inside = (pos, bbox) ->
  bbox[0] <= pos[0] and pos[0] < bbox[2] and bbox[1] <= pos[1] and pos[1] < bbox[3]


app.length = (points, save=false) ->
  sum = 0
  prev = null

  for point in points
    unless prev?
      prev = point
      if save then prev.push(sum)
      continue
    dx = point[0] - prev[0]
    dy = point[1] - prev[1]
    delta = Math.sqrt(dx*dx + dy*dy)
    if save then point.push(sum += delta)
    prev = point

  return sum


app.along = (points, distance) ->
  prev = null
  for point in points
    unless prev?
      prev = point
      continue
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
    prev = point
