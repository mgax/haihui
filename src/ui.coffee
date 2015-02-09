PXKM = 6250  # convert pixels to kilometers


index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


initialize = (db) ->
  topojson.presimplify(db.topo)
  topojson.presimplify(db.dem)

  segmentLayer = topojson.feature(db.topo, db.topo.objects.segments).features
  segmentMap = index(segmentLayer)

  poiLayer = topojson.feature(db.topo, db.topo.objects.poi).features
  contourLayer = topojson.feature(db.dem, db.dem.objects.contour).features

  for route in db.routes
    for id in route.segments
      segment = segmentMap.get(id)
      segment.properties.symbols = [] unless segment.properties.symbols?
      segment.properties.symbols.push(route.symbol)

  width = 1
  height = 1
  center = [(db.bbox[0] + db.bbox[2]) / 2, (db.bbox[1] + db.bbox[3]) / 2]
  s0 = 1
  sc = 1
  t0 = [0, 0]
  tr = [0, 0]
  f0 = 1
  location = null

  projection = d3.geo.albers()
      .center([0, center[1]])
      .rotate([-center[0], 0])
      .parallels([center[1] - 5, center[1] + 5])
      .scale(1)

  _sw = projection(db.bbox.slice(0, 2))
  _ne = projection(db.bbox.slice(2, 4))
  boxWidth = _ne[0] - _sw[0]
  boxHeight = _sw[1] - _ne[1]

  zoom = d3.behavior.zoom()
      .scaleExtent([1, 1000])

  simplify = d3.geo.transform(
    point: (x, y, z) ->
      if z? and z >= f0 / sc / 300
        [a, b] = projection([x, y])
        return @stream.point(a, b)
  )

  path = d3.geo.path()
      .projection(simplify)

  svg = d3.select('body').append('svg')

  segments = svg.append('g')
  contours = svg.append('g')
  symbols = svg.append('g')
  locationg = svg.append('g').attr('class', 'location')

  locationg.append('circle')
      .attr('class', 'midpoint')
      .attr('r', 2)

  locationg.append('circle')
      .attr('class', 'accuracy')

  svg.append('rect')
      .attr('class', 'zoomrect')
      .call(zoom)

  segments.selectAll('.segment')
      .data(segmentLayer)
    .enter().append('path')
      .attr('class', 'segment')

  contours.selectAll('.contour')
      .data(contourLayer)
    .enter().append('path')
      .attr('class', 'contour')
      .attr('id', (d) -> "contour-#{d.id}")

  render = ->
    projection
        .scale(s0 * sc)
        .translate([t0[0] * sc + tr[0], t0[1] * sc + tr[1]])

    segments.selectAll('.segment')
        .attr('d', path)

    contours.selectAll('.contour')
        .attr('d', path)

    contours.selectAll('.contour-label').remove()

    for ring in contourLayer
      length = turf.lineDistance(ring, 'kilometers') * (s0 * sc) / PXKM
      labelCount = Math.floor(length / 500)
      for n in d3.range(0, labelCount)
        contours.append('text')
            .attr('class', 'contour-label')
            .append('textPath')
              .attr('xlink:href', "#contour-#{ring.id}")
              .attr('startOffset', "#{(n + .5) / labelCount * 100}%")
              .text(ring.properties.elevation)

  renderSymbols = ->
    symbols.selectAll('.symbol').remove()

    interval = 80 * PXKM / (s0 * sc)
    segmentSymbols = []
    for segment in segmentLayer
      length = turf.lineDistance(segment, 'kilometers')
      for n in d3.range(0, d3.round(length / interval))
        point = turf.along(segment, interval * (n + 0.5), 'kilometers')
        point.properties = {symbols: segment.properties.symbols}
        [x, y] = projection(point.geometry.coordinates)
        if x > 0 and x < width and y > 0 and y < height
          segmentSymbols.push(point)

    symbols.selectAll('.segmentSymbol').data(segmentSymbols)
      .enter().append('g')
        .attr('class', 'symbol segmentSymbol')
        .each (d) ->
          for i in d3.range(0, d.properties.symbols.length)
            dx = - d3.round(13 / 2 * (d.properties.symbols.length - 1))
            g = d3.select(@).append('g')
                .attr('transform', "translate(#{i * 13 + dx},0)")
            app.symbol.osmc(d.properties.symbols[i])(g)

    poiSymbols = []
    for poi in poiLayer
      [x, y] = projection(poi.geometry.coordinates)
      if x > 0 and x < width and y > 0 and y < height
        poiSymbols.push(poi)

    symbols.selectAll('.poiSymbol').data(poiSymbols)
      .enter().append('g')
        .attr('class', 'symbol poiSymbol')
        .each (poi) ->
          app.symbol[poi.properties.type](d3.select(@))

    updateSymbols()

  updateSymbols = ->
    symbols.selectAll('.symbol')
        .attr 'transform', (d) ->
          "translate(#{d3.round(d) for d in projection(d.geometry.coordinates)})"

  showLocation = () ->
    g = svg.select('.location')

    unless location?
      g.style('display', 'none')
      return

    xy = projection(location.pos)
    ra = location.accuracy / 20000000 * 180
    xya = projection([location.pos[0], location.pos[1] + ra])

    g.style('display', null)
        .attr('transform', "translate(#{xy})")

    g.select('.accuracy')
        .attr('r', xy[1] - xya[1])

  resize = ->
    width = parseInt(d3.select('body').style('width'))
    height = parseInt(d3.select('body').style('height'))

    projection.scale(s0 = d3.min([width / boxWidth, height / boxHeight]))
    f0 = (db.bbox[2] - db.bbox[0]) / boxWidth / s0

    svg.select('.zoomrect')
        .attr('width', width)
        .attr('height', height)

    projection.translate(t0 = [width / 2, height / 2])

    zoom.scale(sc = 1).translate(tr = [0, 0])

    render()
    renderSymbols()
    showLocation()

  zoom.on 'zoom', ->
    tr = d3.event.translate
    sc = d3.event.scale
    render()
    updateSymbols()
    showLocation()

  zoom.on('zoomend', renderSymbols)
  d3.select(window).on('resize', resize)
  resize()

  positionOk = (evt) ->
    coords = evt.coords
    location = {
      pos: [coords.longitude, coords.latitude]
      accuracy: coords.accuracy
    }
    showLocation()

  positionErr = ->
    location = null
    showLocation()

  navigator.geolocation.watchPosition(positionOk, positionErr)


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    initialize(db)
