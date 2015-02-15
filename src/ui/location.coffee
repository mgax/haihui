LOCATION_OFF = 0
LOCATION_SHOW = 1
LOCATION_TRACK = 2

app.location = (options) ->
  map = options.map
  locationg = options.locationg
  locationbuttong = options.locationbuttong

  location = null
  locationMode = LOCATION_OFF
  locationWatch = null

  locationg.append('circle')
      .attr('class', 'midpoint')
      .attr('r', 2)

  locationg.append('circle')
      .attr('class', 'accuracy')

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

  showLocation = () ->
    unless location?
      locationg.style('display', 'none')
      return

    xy = map.projection(location.pos)
    ra = location.accuracy / app.DEGM
    xya = map.projection([location.pos[0], location.pos[1] + ra])

    locationg.style('display', null)
        .attr('transform', "translate(#{xy})")

    locationg.select('.accuracy')
        .attr('r', xy[1] - xya[1])

  map.dispatch.on 'zoom.location', ->
    showLocation()
    positionDisableTracking()

  map.dispatch.on 'redraw.location', ->
    showLocation()

  positionOk = (evt) ->
    coords = evt.coords
    location = {
      pos: [coords.longitude, coords.latitude]
      accuracy: coords.accuracy
    }
    positionUpdate()

  positionUpdate = ->
    showLocation()
    if locationMode == LOCATION_TRACK and location
      pos = location.pos
      if app.inside(location.pos, map.db.bbox)
        map.centerAt(location.pos)

  positionDisableTracking = ->
    if locationMode == LOCATION_TRACK
      locationMode = LOCATION_SHOW
      locationbuttong.classed('tracking', false)

  positionHide = ->
    location = null
    showLocation()
