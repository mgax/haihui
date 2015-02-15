siFormat = d3.format('s')
distanceFormat = (d) -> if d == 0 then '0' else "#{siFormat(d)}m"


app.scale = (options) ->
  map = options.map
  scaleg = options.scaleg

  renderScale = ->
    deg_150px = (map.projection.invert([150, 0])[0] - map.projection.invert([0, 0])[0])
    mapscale = d3.scale.linear()
     .domain([0, deg_150px])
     .rangeRound([0, 150])

    scaleg.selectAll().remove()
    axis = d3.svg.axis()
        .scale(mapscale)
        .orient('bottom')
        .ticks(2)
        .tickSize(6, 0)
        .tickFormat(distanceFormat)
    scaleg.call(axis)

  map.dispatch.on('zoom.scale', renderScale)
  map.dispatch.on('redraw.scale', renderScale)
