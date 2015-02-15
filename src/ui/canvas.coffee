app.canvas = (options) ->
  map = options.map
  bbox = map.db.bbox

  extent = {
    w: d3.max([-bbox[0], bbox[2]]) * 2
    h: d3.max([-bbox[1], bbox[3]]) * 2
  }

  proj = proj4(map.db.projParams)
  map.wgsProjection = (p) -> [x, y] = proj.forward(p); return [+x, +y]

  projection = map.projection = ([x, y]) -> [
    (x - bbox[0]) * map.sc + map.tr[0]
    (bbox[3] - y) * map.sc + map.tr[1]
  ]

  projection.invert = ([px, py]) -> [
    bbox[0] + (px - map.tr[0]) / map.sc
    bbox[3] - (py - map.tr[1]) / map.sc
  ]

  projection.stream = (s) -> {
    point: (x, y, z) -> [px, py] = projection([x, y]); s.point(px, py, z)
    sphere: -> s.sphere()
    lineStart: -> s.lineStart()
    lineEnd: -> s.lineEnd()
    polygonStart: -> s.polygonStart()
    polygonEnd: -> s.polygonEnd()
    valid: true
  }

  zoom = d3.behavior.zoom()

  simplify = d3.geo.transform(
    point: (x, y, z) ->
      if z? and z >= 300 / map.sc
        return @stream.point(x, y)
  )

  clip = d3.geo.clipExtent()

  map.path = d3.geo.path()
      .projection(stream: (s) -> simplify.stream(clip.stream(projection.stream(s))))

  backLayer = d3.select('body').append('svg').attr('class', 'backLayer')
  symbolLayer = d3.select('body').append('svg').attr('class', 'symbolLayer')
  uiLayer = d3.select('body').append('svg').attr('class', 'uiLayer')

  canvas = {}
  canvas.contours = backLayer.append('g')
  canvas.features = backLayer.append('g')
  canvas.symbols = symbolLayer.append('g')
  canvas.locationg = symbolLayer.append('g').attr('class', 'location')

  uiLayer.append('rect')
      .attr('class', 'zoomrect')
      .call(zoom)

  actionbar = canvas.actionbar = uiLayer.append('g')
      .attr('class', 'actionbar')

  resize = ->
    if map.sc?
      oldCenter = [map.width / 2, map.height / 2]

    map.width = parseInt(d3.select('body').style('width'))
    map.height = parseInt(d3.select('body').style('height'))
    minScale = d3.min([map.width / extent.w, map.height / extent.h])

    if map.sc?
      sc = map.sc
      tr = map.tr
      center = projection.invert(oldCenter)

    else
      sc = minScale
      tr = [0, 0]
      center = [0, 0]

    uiLayer.select('.zoomrect')
        .attr('width', map.width)
        .attr('height', map.height)

    updateProjection(sc, tr)
    map.centerAt(center, map.sc)
    zoom.scaleExtent([minScale, 3])

    actionbar.attr('transform', "translate(0, #{map.height - app.ACTIONBAR_HEIGHT})")
    actionbar.select('.background').attr('width', map.width)

    resetBackLayer()
    map.dispatch.redraw()

  updateProjection = (new_sc, new_tr) ->
    map.sc = new_sc
    map.tr = new_tr
    clip.extent([projection.invert([0, map.height]), projection.invert([map.width, 0])])

  resetBackLayer = ->
    transformBackLayer((map.scBase = map.sc), (map.trBase = map.tr))

  transformBackLayer = (scZoom, trZoom) ->
    scDelta = scZoom / map.scBase
    trDelta = [
      trZoom[0] - map.trBase[0] * scDelta + (scDelta - 1) * map.width / 2
      trZoom[1] - map.trBase[1] * scDelta + (scDelta - 1) * map.height / 2
    ]
    transform = "translate3d(#{trDelta[0]}px,#{trDelta[1]}px,0px) scale(#{scDelta})"
    backLayer.attr('style', "-webkit-transform: #{transform}")

  map.centerAt = (pos, new_sc) ->
    updateProjection(new_sc, [0, 0])
    xy = projection(pos)
    new_tr = [map.width / 2 - xy[0], map.height / 2 - xy[1]]
    zoom.scale(new_sc).translate(new_tr)
    updateProjection(new_sc, new_tr)
    map.dispatch.redraw()

  zoom.on 'zoom', ->
    updateProjection(d3.event.scale, d3.event.translate)
    transformBackLayer(d3.event.scale, d3.event.translate)
    map.dispatch.zoom()

  zoom.on 'zoomend', ->
    resetBackLayer()
    map.dispatch.zoomend()

  d3.select(window).on('resize', resize)
  map.dispatch.on('ready.canvas', resize)

  return canvas
