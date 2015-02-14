app.canvas = (options) ->
  map = options.map
  bbox = map.db.bbox

  map.width = 1
  map.height = 1
  center = [(bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2]
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

  _sw = projection(bbox.slice(0, 2))
  _ne = projection(bbox.slice(2, 4))
  boxWidth = _ne[0] - _sw[0]
  boxHeight = _sw[1] - _ne[1]

  zoom = d3.behavior.zoom()
      .scaleExtent([1, 1000])

  simplify = d3.geo.transform(
    point: (x, y, z) ->
      if z? and z >= f0 / map.sc / 300
        return @stream.point(x, y)
  )

  clip = d3.geo.clipExtent()

  map.path = d3.geo.path()
      .projection(stream: (s) -> simplify.stream(projection.stream(clip.stream(s))))

  svg = d3.select('body').append('svg')

  canvas = {}
  canvas.contours = svg.append('g')
  canvas.features = svg.append('g')
  canvas.locationg = svg.append('g').attr('class', 'location')

  svg.append('rect')
      .attr('class', 'zoomrect')
      .call(zoom)

  actionbar = canvas.actionbar = svg.append('g')
      .attr('class', 'actionbar')

  resize = ->
    map.width = parseInt(d3.select('body').style('width'))
    map.height = parseInt(d3.select('body').style('height'))

    clip.extent([[0, 0], [map.width, map.height]])

    projection.scale(map.s0 = d3.min([map.width / boxWidth, map.height / boxHeight]))
    f0 = (bbox[2] - bbox[0]) / boxWidth / map.s0

    svg.select('.zoomrect')
        .attr('width', map.width)
        .attr('height', map.height)

    projection.translate(t0 = [map.width / 2, map.height / 2])

    zoom.scale(1).translate([0, 0])
    updateProjection(1, [0, 0])

    actionbar.attr('transform', "translate(0, #{map.height - app.ACTIONBAR_HEIGHT})")
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
  map.dispatch.on('ready.canvas', resize)

  return canvas
