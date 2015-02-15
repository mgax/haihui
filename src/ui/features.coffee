app.features = (options) ->
  map = options.map
  db = map.db

  rivers = options.g.append('g')
  highways = options.g.append('g')
  segments = options.g.append('g')
  symbols = options.symbols

  segmentLayer = topojson.feature(db.topo, db.topo.objects.segments).features
  segmentMap = app.index(segmentLayer)
  for s in segmentLayer
    s.properties.length = app.length(s.geometry.coordinates, true)

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
        point = app.along(segment.geometry.coordinates, interval * (n + 0.5))
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
    updateSymbols()

  map.dispatch.on 'zoomend.features', ->
    render()
    renderSymbols()
