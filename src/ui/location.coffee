ACCURACY_LIMIT = 1000  # 1km
LOCATION_OFF = 0
LOCATION_WAIT = 1
LOCATION_SHOW = 2
LOCATION_TRACK = 3

app.location = (options) ->
  map = options.map
  locationg = options.locationg
  button = options.locationbuttong

  location = null
  locationMode = null
  locationWatch = null

  locationg.append('circle')
      .attr('class', 'midpoint')
      .attr('r', 6)

  locationg.append('circle')
      .attr('class', 'accuracy')

  setMode = (mode) ->
    locationMode = mode
    button.attr 'class', switch locationMode
      when LOCATION_OFF   then 'locationbutton'
      when LOCATION_WAIT  then 'locationbutton waiting'
      when LOCATION_SHOW  then 'locationbutton showing'
      when LOCATION_TRACK then 'locationbutton showing tracking'

  setMode(LOCATION_OFF)

  button.append('rect')
      .attr('class', 'buttonmask')
      .attr('x', -10)
      .attr('y', -10)
      .attr('width', 20)
      .attr('height', 20)

  button.on 'click', ->
      switch locationMode
        when LOCATION_OFF
          setMode(LOCATION_WAIT)
          locationWatch = navigator.geolocation.watchPosition(positionOk, positionHide, enableHighAccuracy: true)

        when LOCATION_WAIT
          setMode(LOCATION_OFF)
          navigator.geolocation.clearWatch(locationWatch)

        when LOCATION_SHOW
          setMode(LOCATION_TRACK)
          positionUpdate()

        when LOCATION_TRACK
          setMode(LOCATION_OFF)
          navigator.geolocation.clearWatch(locationWatch)
          positionHide()

  app.symbol.locationbutton(button)

  showLocation = () ->
    if map.zooming
      return

    unless location?
      locationg.style('display', 'none')
      return

    xy = map.projection(map.wgsProjection(location.pos))
    locationg.style('display', null)
        .attr('transform', "translate(#{xy})")

    locationg.select('.accuracy')
        .attr('r', d3.max([location.accuracy * map.sc, 8]))

  map.dispatch.on 'zoom.location', ->
    positionDisableTracking()

  map.dispatch.on 'zoomend.location', ->
    showLocation()

  map.dispatch.on 'redraw.location', ->
    showLocation()

  positionOk = (evt) ->
    coords = evt.coords
    return if coords.accuracy > ACCURACY_LIMIT
    pos = [coords.longitude, coords.latitude]
    return unless app.inside(map.wgsProjection(pos), map.db.bbox)
    location = {pos: pos, accuracy: coords.accuracy}

    center = false
    if locationMode == LOCATION_WAIT
      setMode(LOCATION_SHOW)
      center = true
    positionUpdate(center)

  positionUpdate = (center) ->
    showLocation()
    if (locationMode == LOCATION_TRACK or center) and location
      point = map.wgsProjection(location.pos)
      if app.inside(point, map.db.bbox)
        scaleTarget = d3.min([map.width, map.height]) / 3 / location.accuracy
        scale = d3.min([scaleTarget, 3])
        map.centerAt(point, scale)

  positionDisableTracking = ->
    if locationMode == LOCATION_TRACK
      setMode(LOCATION_SHOW)

  positionHide = ->
    location = null
    showLocation()
