app.features = (options) ->
  map = options.map
  db = map.db
  map.debug.collisions = false

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

  labelWidthG = symbols.append('g')
      .attr('class', 'symbolLabel')
      .attr('tarnsform', 'translate(0,-100)')
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
    symbols.selectAll('.symbolLabel').remove()

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
                hw: 6.5 * segment.properties.symbols.length
                hh: 6.5
              }
              symbolList.push(symbol)

    for poi in poiLayer
      xyproj = map.projection(poi.geometry.coordinates)
      x = d3.round(xyproj[0])
      y = d3.round(xyproj[1])
      if x > 0 and x < map.width and y > 0 and y < map.height
        if (symbolType = app.symbol[poi.properties.type])?
          symbol = {
            properties: poi.properties
            x: x
            y: y
            hw: symbolType.mask.hw
            hh: symbolType.mask.hh
          }
          symbolList.push(symbol)

    symbols.selectAll('.symbol')
        .data(symbolList)
      .enter().append('g')
        .attr('class', 'symbol')
        .attr('transform', (d) -> "translate(#{d.x},#{d.y})")
        .each(app.symbol.render)

    qt = (d3.geom.quadtree()
        .extent([[0, 0], [map.width, map.height]])
        .x (d) -> d.x
        .y (d) -> d.y
        )([])

    # search distance
    sw = d3.max(symbolList, (s) -> s.hw)
    sh = d3.max(symbolList, (s) -> s.hh)

    collides = (x, y, hw, hh) ->
      tx1 = x - hw - sw
      ty1 = y - hh - sh
      tx2 = x + hw + sw
      ty2 = y + hh + sh
      hit = false
      qt.visit (quad, qx1, qy1, qx2, qy2) ->
        if (point = quad.point)?
          dx = Math.abs(point.x - x)
          dy = Math.abs(point.y - y)
          if dx < hw + point.hw and dy < hh + point.hh
            hit = true
        return qx1 > tx2 or qx2 < tx1 or qy1 > ty2 or qy2 < ty1
      return hit

    for symbol in symbolList.slice().reverse()
      continue if symbol.segmentSymbol
      size = symbol.properties.labelSize
      mask = app.symbol[symbol.properties.type].mask
      thw = size.w / 2
      thh = size.h / 2
      tx = symbol.x + mask.hw + thw + 1
      ty = symbol.y + mask.hh - 2 * thh
      unless collides(tx, ty, thw + 1, thh + 1)
        if (name = symbol.properties.name)?
          g = symbols.append('g')
              .attr('class', 'symbolLabel')
              .attr('transform', "translate(#{tx - thw},#{ty - thh - size.dy})")
          app.symbol.textWithHalo(g, name)
          qt.add(x: tx, y: ty, hw: thw, hh: thh, labelFor: symbol)

    if map.debugCollisions
      qtNodes = []
      qt.visit((node) -> if node.point then qtNodes.push(node.point); true)
      symbols.selectAll('.quadtreeRect').data(qtNodes)
        .enter().append('rect')
          .attr('class', 'symbol quadtreeRect')
          .attr('x', (d) -> d.x - d.hw)
          .attr('y', (d) -> d.y - d.hh)
          .attr('width', (d) -> d.hw * 2)
          .attr('height', (d) -> d.hh * 2)
          .attr('fill', 'none')
          .attr('stroke-width', 1)
          .attr('stroke', 'red')

  map.dispatch.on 'redraw.features', ->
    render()

  map.dispatch.on 'zoomend.features', ->
    render()
