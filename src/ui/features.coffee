app.features = (options) ->
  map = options.map
  db = map.db

  lakes = options.g.append('g')
  rivers = options.g.append('g')
  highways = options.g.append('g')
  segments = options.g.append('g')
  symbols = options.symbols

  lakesLayer = topojson.feature(db.topo, db.topo.objects.lakes).features
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

  labelWidthG = symbols.append('g').attr('transform', "translate(0,-100)")
  app.symbol.calculateLabelWidth(labelWidthG, poiLayer)
  labelWidthG.remove()

  segments.selectAll('.segment')
      .data(segmentLayer)
    .enter().append('path')
      .attr('class', 'segment')

  lakes.selectAll('.lake')
      .data(lakesLayer)
    .enter().append('path')
      .attr('class', 'lake')

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

    lakes.selectAll('.lake')
        .attr('d', map.path)

    rivers.selectAll('.river')
        .attr('d', map.path)

    highways.selectAll('.highway')
        .attr('d', map.path)

    symbols.selectAll('.symbol').remove()

    interval = 80 / map.sc
    symbolList = []
    for segment in segmentLayer
      length = segment.properties.length
      for n in d3.range(0, d3.round(length / interval))
        point = app.along(segment.geometry.coordinates, interval * (n + 0.5))
        if segment.properties.symbols
          point.properties = {symbols: segment.properties.symbols}
          if app.inside(point.geometry.coordinates, db.bbox)
            xyproj = map.projection(point.geometry.coordinates)
            x = d3.round(xyproj[0])
            y = d3.round(xyproj[1])
            if app.inside([x, y], [0, 0, map.width, map.height])
              symbol = {
                segmentSymbol: true
                properties: point.properties
                x: x
                y: y
              }
              symbolList.push(symbol)

    for poi in poiLayer
      xyproj = map.projection(poi.geometry.coordinates)
      x = d3.round(xyproj[0])
      y = d3.round(xyproj[1])
      if x > 0 and x < map.width and y > 0 and y < map.height
        if app.symbol[poi.properties.type]
          symbol = {properties: poi.properties, x: x, y: y}
          symbolList.push(symbol)

    symbols.selectAll('.symbol')
        .data(symbolList)
      .enter().append('g')
        .attr('class', 'symbol')
        .attr('transform', (d) -> "translate(#{d.x},#{d.y})")
        .each(app.symbol.render)

  map.dispatch.on 'redraw.features', ->
    render()

  map.dispatch.on 'zoomend.features', ->
    render()
