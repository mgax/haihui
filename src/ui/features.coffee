segmentLength = (segment, save=false) ->
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


along = (segment, distance) ->
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


app.features = (options) ->
  map = options.map
  db = map.db

  rivers = options.g.append('g')
  highways = options.g.append('g')
  segments = options.g.append('g')
  symbols = options.g.append('g')

  segmentLayer = topojson.feature(db.topo, db.topo.objects.segments).features
  segmentMap = app.index(segmentLayer)
  for segment in segmentLayer
    segmentLength(segment, true)

  poiLayer = topojson.feature(db.topo, db.topo.objects.poi).features
  riversLayer = topojson.feature(db.topo, db.topo.objects.rivers).features
  highwaysLayer = topojson.feature(db.topo, db.topo.objects.highways).features

  for route in db.routes
    for id in route.segments
      if route.symbol?
        segment = segmentMap.get(id)
        segment.properties.symbols = [] unless segment.properties.symbols?
        segment.properties.symbols.push(route.symbol)

  segments.selectAll('.segment')
      .data(segmentLayer)
    .enter().append('path')
      .attr('class', 'segment')

  rivers.selectAll('.river')
      .data(riversLayer)
    .enter().append('path')
      .attr('class', 'river')

  highways.selectAll('.highway')
      .data(highwaysLayer)
    .enter().append('path')
      .attr('class', (d) -> "highway highway-#{d.properties.grade}")

  render = ->
    segments.selectAll('.segment')
        .attr('d', map.path)

    rivers.selectAll('.river')
        .attr('d', map.path)

    highways.selectAll('.highway')
        .attr('d', map.path)

  renderSymbols = ->
    symbols.selectAll('.symbol').remove()

    interval = 80 / map.sc
    segmentSymbols = []
    for segment in segmentLayer
      length = segment.properties.length
      for n in d3.range(0, d3.round(length / interval))
        point = along(segment, interval * (n + 0.5))
        point.properties = {symbols: segment.properties.symbols}
        [x, y] = map.projection(point.geometry.coordinates)
        if app.inside([x, y], [0, 0, map.width, map.height])
          segmentSymbols.push(point)

    symbols.selectAll('.segmentSymbol').data(segmentSymbols)
      .enter().append('g')
        .attr('class', 'symbol segmentSymbol')
        .each (d) ->
          return unless d.properties.symbols
          for i in d3.range(0, d.properties.symbols.length)
            dx = - d3.round(13 / 2 * (d.properties.symbols.length - 1))
            g = d3.select(@).append('g')
                .attr('transform', "translate(#{i * 13 + dx},0)")
            app.symbol.osmc(d.properties.symbols[i])(g)

    poiSymbols = []
    for poi in poiLayer
      [x, y] = map.projection(poi.geometry.coordinates)
      if x > 0 and x < map.width and y > 0 and y < map.height
        poiSymbols.push(poi)

    symbols.selectAll('.poiSymbol').data(poiSymbols)
      .enter().append('g')
        .attr('class', 'symbol poiSymbol')
        .each (poi) ->
          if (drawSymbol = app.symbol[poi.properties.type])?
            drawSymbol(d3.select(@))

    updateSymbols()

  updateSymbols = ->
    symbols.selectAll('.symbol')
        .attr 'transform', (d) ->
          "translate(#{d3.round(d) for d in map.projection(d.geometry.coordinates)})"

  map.dispatch.on 'redraw.features', ->
    render()
    renderSymbols()

  map.dispatch.on 'zoom.features', ->
    render()
    updateSymbols()
  map.dispatch.on('zoomend.features', renderSymbols)
