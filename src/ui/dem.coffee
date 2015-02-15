app.dem = (options) ->
  map = options.map
  contours = options.contours

  contourLayer = topojson.feature(map.db.dem, map.db.dem.objects.contour).features

  contours.selectAll('.contour')
      .data(contourLayer)
    .enter().append('path')
      .attr('class', 'contour')
      .classed('contour-minor', (d) -> d.properties.elevation % 300)
      .attr('id', (d) -> "contour-#{d.id}")

  renderContours = ->
    contours.selectAll('.contour')
        .attr('d', map.path)

    contours.selectAll('.contour-label').remove()

    for ring in contourLayer
      continue if ring.properties.elevation % 300
      contours.append('text')
          .attr('class', 'contour-label')
          .append('textPath')
            .attr('xlink:href', "#contour-#{ring.id}")
            .attr('startOffset', "50%")
            .text(ring.properties.elevation)

  map.dispatch.on('redraw.contours', renderContours)
  map.dispatch.on('zoomend.contours', renderContours)
