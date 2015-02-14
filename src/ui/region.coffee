PXKM = 6250  # convert pixels to kilometers
DEGM = 20000000 / 180 # convert degrees to meters
ACTIONBAR_HEIGHT = 30
LOCATION_OFF = 0
LOCATION_SHOW = 1
LOCATION_TRACK = 2
siFormat = d3.format('s')
distanceFormat = (d) -> if d == 0 then '0' else "#{siFormat(d)}m"


index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


inside = (pos, bbox) ->
  bbox[0] <= pos[0] and pos[0] < bbox[2] and bbox[1] <= pos[1] and pos[1] < bbox[3]


initialize = (db) ->
  topojson.presimplify(db.topo)
  topojson.presimplify(db.dem)

  segmentLayer = topojson.feature(db.topo, db.topo.objects.segments).features
  segmentMap = index(segmentLayer)

  poiLayer = topojson.feature(db.topo, db.topo.objects.poi).features
  riversLayer = topojson.feature(db.topo, db.topo.objects.rivers).features
  highwaysLayer = topojson.feature(db.topo, db.topo.objects.highways).features
  contourLayer = topojson.feature(db.dem, db.dem.objects.contour).features

  for route in db.routes
    for id in route.segments
      if route.symbol?
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
  locationMode = LOCATION_OFF
  locationWatch = null

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

  clip = d3.geo.clipExtent()

  path = d3.geo.path()
      .projection(stream: (s) -> simplify.stream(clip.stream(s)))

  svg = d3.select('body').append('svg')

  contours = svg.append('g')
  rivers = svg.append('g')
  highways = svg.append('g')
  segments = svg.append('g')
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

  actionbar = svg.append('g')
      .attr('class', 'actionbar')

  actionbar.append('rect')
      .attr('class', 'background')
      .attr('height', ACTIONBAR_HEIGHT)

  scaleg = actionbar.append('g')
      .attr('class', 'scale')
      .attr('transform', "translate(10.5, 5.5)")

  locationbuttong = actionbar.append('g')
      .attr('class', 'locationbutton')
      .attr('transform', "translate(200, #{ACTIONBAR_HEIGHT / 2})")

  locationbuttong.append('g')
      .attr('class', 'symbol-locationbutton')

  locationbuttong.append('rect')
      .attr('class', 'buttonmask')
      .attr('x', -15)
      .attr('y', -15)
      .attr('width', 30)
      .attr('height', 30)
      .on 'click', ->
        switch locationMode
          when LOCATION_OFF
            locationMode = LOCATION_SHOW
            locationWatch = navigator.geolocation.watchPosition(positionOk, positionHide)
            locationbuttong.classed('locating', true)

          when LOCATION_SHOW
            locationMode = LOCATION_TRACK
            locationbuttong.classed('tracking', true)
            positionUpdate()

          when LOCATION_TRACK
            locationMode = LOCATION_OFF
            locationbuttong.classed('tracking', false)
            locationbuttong.classed('locating', false)
            navigator.geolocation.clearWatch(locationWatch)
            positionHide()

  app.symbol.locationbutton(locationbuttong.select('.symbol-locationbutton'))

  segments.selectAll('.segment')
      .data(segmentLayer)
    .enter().append('path')
      .attr('class', 'segment')

  contours.selectAll('.contour')
      .data(contourLayer)
    .enter().append('path')
      .attr('class', 'contour')
      .classed('contour-minor', (d) -> d.properties.elevation % 300)
      .attr('id', (d) -> "contour-#{d.id}")

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
        .attr('d', path)

    rivers.selectAll('.river')
        .attr('d', path)

    highways.selectAll('.highway')
        .attr('d', path)

    contours.selectAll('.contour')
        .attr('d', path)

    contours.selectAll('.contour-label').remove()

    for ring in contourLayer
      continue if ring.properties.elevation % 300
      length = turf.lineDistance(ring, 'kilometers') * (s0 * sc) / PXKM
      contours.append('text')
          .attr('class', 'contour-label')
          .append('textPath')
            .attr('xlink:href', "#contour-#{ring.id}")
            .attr('startOffset', "50%")
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
          return unless d.properties.symbols
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
          if (drawSymbol = app.symbol[poi.properties.type])?
            drawSymbol(d3.select(@))

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
    ra = location.accuracy / DEGM
    xya = projection([location.pos[0], location.pos[1] + ra])

    g.style('display', null)
        .attr('transform', "translate(#{xy})")

    g.select('.accuracy')
        .attr('r', xy[1] - xya[1])

  renderScale = ->
    deg_150px = (projection.invert([150, 0])[0] - projection.invert([0, 0])[0])
    mapscale = d3.scale.linear()
     .domain([0, deg_150px * DEGM])
     .rangeRound([0, 150])

    scaleg.selectAll().remove()
    axis = d3.svg.axis()
        .scale(mapscale)
        .orient('bottom')
        .ticks(2)
        .tickSize(6, 0)
        .tickFormat(distanceFormat)
    scaleg.call(axis)

  resize = ->
    width = parseInt(d3.select('body').style('width'))
    height = parseInt(d3.select('body').style('height'))

    clip.extent([[0, 0], [width, height]])

    projection.scale(s0 = d3.min([width / boxWidth, height / boxHeight]))
    f0 = (db.bbox[2] - db.bbox[0]) / boxWidth / s0

    svg.select('.zoomrect')
        .attr('width', width)
        .attr('height', height)

    projection.translate(t0 = [width / 2, height / 2])

    zoom.scale(1).translate([0, 0])
    updateProjection(1, [0, 0])

    actionbar.attr('transform', "translate(0, #{height - ACTIONBAR_HEIGHT})")
    actionbar.select('.background').attr('width', width)

    redraw()

  redraw = ->
    render()
    renderSymbols()
    showLocation()
    renderScale()

  updateProjection = (new_sc, new_tr) ->
    sc = new_sc
    tr = new_tr
    projection
        .scale(s0 * sc)
        .translate([t0[0] * sc + tr[0], t0[1] * sc + tr[1]])

  centerAt = (pos) ->
    new_sc = 8000000 / s0
    updateProjection(new_sc, [0, 0])
    xy = projection(pos)
    new_tr = [width / 2 - xy[0], height / 2 - xy[1]]
    zoom.scale(new_sc).translate(new_tr)
    updateProjection(new_sc, new_tr)
    redraw()

  zoom.on 'zoom', ->
    updateProjection(d3.event.scale, d3.event.translate)
    render()
    updateSymbols()
    showLocation()
    renderScale()
    positionDisableTracking()

  zoom.on('zoomend', renderSymbols)
  d3.select(window).on('resize', resize)
  resize()

  positionOk = (evt) ->
    coords = evt.coords
    location = {
      pos: [coords.longitude, coords.latitude]
      accuracy: coords.accuracy
    }
    positionUpdate()

  positionUpdate = ->
    showLocation()
    if locationMode == LOCATION_TRACK
      pos = location.pos
      if inside(location.pos, db.bbox)
        centerAt(location.pos)

  positionDisableTracking = ->
    if locationMode == LOCATION_TRACK
      locationMode = LOCATION_SHOW
      locationbuttong.classed('tracking', false)

  positionHide = ->
    location = null
    showLocation()


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    initialize(db)