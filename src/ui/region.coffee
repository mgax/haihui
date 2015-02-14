app.PXKM = 6250  # convert pixels to kilometers
app.DEGM = 20000000 / 180 # convert degrees to meters
ACTIONBAR_HEIGHT = 30


app.index = (objects) ->
  map = d3.map()
  for o in objects
    map.set(o.id, o)
  return map


app.inside = (pos, bbox) ->
  bbox[0] <= pos[0] and pos[0] < bbox[2] and bbox[1] <= pos[1] and pos[1] < bbox[3]


initialize = (db) ->
  map = {
    db: db
    dispatch: d3.dispatch('zoom', 'zoomend', 'redraw')
  }

  topojson.presimplify(db.topo)
  topojson.presimplify(db.dem)

  map.width = 1
  map.height = 1
  center = [(db.bbox[0] + db.bbox[2]) / 2, (db.bbox[1] + db.bbox[3]) / 2]
  map.s0 = 1
  map.sc = 1
  t0 = [0, 0]
  tr = [0, 0]
  f0 = 1

  projection = map.projection = d3.geo.albers()
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
      if z? and z >= f0 / map.sc / 300
        [a, b] = projection([x, y])
        return @stream.point(a, b)
  )

  clip = d3.geo.clipExtent()

  path = map.path = d3.geo.path()
      .projection(stream: (s) -> simplify.stream(clip.stream(s)))

  svg = d3.select('body').append('svg')

  contours = svg.append('g')
  features = svg.append('g')
  locationg = svg.append('g').attr('class', 'location')

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

  app.location(
    map: map
    locationg: locationg
    locationbuttong: locationbuttong
  )

  app.dem(
    map: map
    contours: contours
  )

  app.scale(
    map: map
    scaleg: scaleg
  )

  app.features(
    map: map
    g: features
  )

  resize = ->
    map.width = parseInt(d3.select('body').style('width'))
    map.height = parseInt(d3.select('body').style('height'))

    clip.extent([[0, 0], [map.width, map.height]])

    projection.scale(map.s0 = d3.min([map.width / boxWidth, map.height / boxHeight]))
    f0 = (db.bbox[2] - db.bbox[0]) / boxWidth / map.s0

    svg.select('.zoomrect')
        .attr('width', map.width)
        .attr('height', map.height)

    projection.translate(t0 = [map.width / 2, map.height / 2])

    zoom.scale(1).translate([0, 0])
    updateProjection(1, [0, 0])

    actionbar.attr('transform', "translate(0, #{map.height - ACTIONBAR_HEIGHT})")
    actionbar.select('.background').attr('width', map.width)

    map.dispatch.redraw()

  updateProjection = (new_sc, new_tr) ->
    map.sc = new_sc
    tr = new_tr
    projection
        .scale(map.s0 * map.sc)
        .translate([t0[0] * map.sc + tr[0], t0[1] * map.sc + tr[1]])

  map.centerAt = (pos) ->
    new_sc = 8000000 / map.s0
    updateProjection(new_sc, [0, 0])
    xy = projection(pos)
    new_tr = [map.width / 2 - xy[0], map.height / 2 - xy[1]]
    zoom.scale(new_sc).translate(new_tr)
    updateProjection(new_sc, new_tr)
    map.dispatch.redraw()

  zoom.on 'zoom', ->
    updateProjection(d3.event.scale, d3.event.translate)
    map.dispatch.zoom()

  zoom.on 'zoomend', ->
    map.dispatch.zoomend()

  d3.select(window).on('resize', resize)
  resize()


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    initialize(db)
