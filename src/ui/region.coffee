app.PXKM = 6250  # convert pixels to kilometers
app.DEGM = 20000000 / 180 # convert degrees to meters
app.ACTIONBAR_HEIGHT = 30


initialize = (db) ->
  map = {
    db: db
    dispatch: d3.dispatch('ready', 'zoom', 'zoomend', 'redraw')
  }

  topojson.presimplify(db.topo)
  topojson.presimplify(db.dem)

  canvas = app.canvas(map: map)

  canvas.actionbar.append('rect')
      .attr('class', 'background')
      .attr('height', app.ACTIONBAR_HEIGHT)

  scaleg = canvas.actionbar.append('g')
      .attr('class', 'scale')
      .attr('transform', "translate(10.5, 5.5)")

  locationbuttong = canvas.actionbar.append('g')
      .attr('class', 'locationbutton')
      .attr('transform', "translate(200, #{app.ACTIONBAR_HEIGHT / 2})")

  app.location(
    map: map
    locationg: canvas.locationg
    locationbuttong: locationbuttong
  )

  app.dem(
    map: map
    contours: canvas.contours
  )

  app.scale(
    map: map
    scaleg: scaleg
  )

  app.features(
    map: map
    g: canvas.features
  )

  map.dispatch.ready()
  return map


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    window.map = initialize(db)
