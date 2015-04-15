app.ACTIONBAR_HEIGHT = 30


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

  canvas.actionbar.append('rect')
      .attr('class', 'background')
      .attr('height', '100%')
      .attr('width', '100%')

  actionbarRight = canvas.actionbar.append('g')

  scaleg = actionbarRight.append('g')
      .attr('class', 'scale')
      .attr('transform', "translate(50.5, 5.5)")

  locationbuttong = actionbarRight.append('g')
      .attr('class', 'locationbutton')
      .attr('transform', "translate(10, #{app.ACTIONBAR_HEIGHT / 2})")

  canvas.actionbar
    .append('text')
      .attr('class', 'logo')
      .attr('transform', "translate(#{5},#{app.ACTIONBAR_HEIGHT / 2 + 8})")
    .append('a')
      .attr('xlink:href', '..')
      .text('haihui')

  placeActionbarRight = ->
    width = parseInt(d3.select('body').style('width'))
    actionbarRight.attr('transform', "translate(#{width - 220},0)")

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

  d3.select('.splash').remove()
  map.dispatch.ready()
  return map


app.load = (url) ->
  d3.json url, (error, db) ->
    if error then return console.error(error)
    window.map = initialize(db)
