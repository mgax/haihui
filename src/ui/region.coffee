app.ACTIONBAR_HEIGHT = 50


initialize = (db) ->
  map = {
    db: db
    dispatch: d3.dispatch('ready', 'zoom', 'zoomend', 'redraw')
    debug: {}
  }

  topojson.presimplify(db.topo)
  topojson.presimplify(db.land)
  topojson.presimplify(db.dem)

  canvas = app.canvas(map: map)

  actionbarRight = canvas.actionbar.append('g')

  scaleg = actionbarRight.append('g')
      .attr('class', 'scale')
      .attr('transform', "translate(82, 15)")

  locationbuttong = actionbarRight
    .append('g')
      .attr('transform', 'scale(2.6)')
    .append('g')
      .attr('class', 'locationbutton')
      .attr('transform', "translate(18, #{app.ACTIONBAR_HEIGHT / 2 / 2.6})")

  noteG = actionbarRight
    .append('g')
      .attr('transform', 'scale(1.7)')
    .append('g')
      .attr('class', 'note')
      .attr('transform', "translate(0, #{app.ACTIONBAR_HEIGHT / 2 / 1.7})")

  canvas.actionbar
    .append('text')
      .attr('class', 'logo')
      .attr('transform', "translate(#{5},#{app.ACTIONBAR_HEIGHT / 2 + 8})")
    .append('a')
      .attr('xlink:href', '..')
      .text('haihui')

  placeActionbarRight = ->
    width = parseInt(d3.select('body').style('width'))
    actionbarRight.attr('transform', "translate(#{width - 250},0)")

  placeActionbarRight()
  d3.select(window).on('resize.placeActionbarRight', placeActionbarRight)

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
    featuresG: canvas.features
    landG: canvas.land
    symbols: canvas.symbols
  )

  app.note(
    map: map
    g: noteG
  )

  d3.select('.splash').remove()
  map.dispatch.ready()
  return map


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    window.map = initialize(db)
