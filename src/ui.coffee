index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


initialize = (map) ->
  segmentLayer = topojson.feature(map.topo, map.topo.objects.segments).features
  segmentMap = index(segmentLayer)

  poiLayer = topojson.feature(map.topo, map.topo.objects.poi).features

  for route in map.routes
    for id in route.segments
      segment = segmentMap.get(id)
      segment.properties.symbols = [] unless segment.properties.symbols?
      segment.properties.symbols.push(route.symbol)

  width = 1
  height = 1
  center = [(map.bbox[0] + map.bbox[2]) / 2, (map.bbox[1] + map.bbox[3]) / 2]
  s0 = 1
  sc = 1
  t0 = [0, 0]
  tr = [0, 0]

  projection = d3.geo.albers()
      .center([0, center[1]])
      .rotate([-center[0], 0])
      .parallels([center[1] - 5, center[1] + 5])
      .scale(1)

  _sw = projection(map.bbox.slice(0, 2))
  _ne = projection(map.bbox.slice(2, 4))
  boxWidth = _ne[0] - _sw[0]
  boxHeight = _sw[1] - _ne[1]

  zoom = d3.behavior.zoom()
      .scaleExtent([1, 1000])

  path = d3.geo.path()
      .projection(projection)

  svg = d3.select('body').append('svg')

  geo = svg.append('g')

  svg.append('rect')
      .attr('class', 'zoomrect')
      .call(zoom)

  geo.selectAll('.way')
      .data(segmentLayer)
    .enter().append('path')
      .attr('class', 'way')

  render = ->
    projection
        .scale(s0 * sc)
        .translate([t0[0] * sc + tr[0], t0[1] * sc + tr[1]])

    geo.selectAll('.way')
        .attr('d', path)

  renderSymbols = ->
    geo.selectAll('.symbol').remove()

    interval = 500000 / (s0 * sc)
    segmentSymbols = []
    for segment in segmentLayer
      length = turf.lineDistance(segment, 'kilometers')
      for n in d3.range(0, d3.round(length / interval))
        point = turf.along(segment, interval * (n + 0.5), 'kilometers')
        [x, y] = projection(point.geometry.coordinates)
        if x > 0 and x < width and y > 0 and y < height
          segmentSymbols.push(
            point: point.geometry.coordinates
            symbols: segment.properties.symbols
          )

    geo.selectAll('.segmentSymbol').data(segmentSymbols)
      .enter().append('g')
        .attr('class', 'symbol segmentSymbol')
        .each (d) ->
          for i in d3.range(0, d.symbols.length)
            dx = - d3.round(13 / 2 * (d.symbols.length - 1))
            g = d3.select(@).append('g')
                .attr('transform', "translate(#{i * 13 + dx},0)")
            app.symbol.osmc(d.symbols[i])(g)

    poiSymbols = []
    for poi in poiLayer
      [x, y] = projection(poi.geometry.coordinates)
      if x > 0 and x < width and y > 0 and y < height
        poiSymbols.push(
          point: poi.geometry.coordinates
          type: poi.properties.type
        )

    geo.selectAll('.poiSymbol').data(poiSymbols)
      .enter().append('g')
        .attr('class', 'symbol poiSymbol')
        .each (d) ->
          app.symbol[d.type](d3.select(@))

    updateSymbols()

  updateSymbols = ->
    geo.selectAll('.symbol')
        .attr 'transform', (d) ->
          "translate(#{d3.round(d) for d in projection(d.point)})"

  resize = ->
    width = parseInt(d3.select('body').style('width'))
    height = parseInt(d3.select('body').style('height'))

    projection.scale(s0 = d3.min([width / boxWidth, height / boxHeight]))

    svg.select('.zoomrect')
        .attr('width', width)
        .attr('height', height)

    projection.translate(t0 = [width / 2, height / 2])

    render()
    renderSymbols()

  zoom.on 'zoom', ->
    tr = d3.event.translate
    sc = d3.event.scale
    render()
    updateSymbols()

  zoom.on('zoomend', renderSymbols)
  d3.select(window).on('resize', resize)
  resize()


d3.json 'build/ciucas.json', (error, map) ->
  if error then return console.error(error)
  initialize(map)
