app.note = (options) ->
  map = options.map

  btn = options.g.append('a')
      .attr('xlink:href', '#')

  btn.append('circle')
      .attr('r', 17)

  btn.append('text')
      .attr('transform', "translate(-3,5)")
      .text('!')

  render = ->
    lngLat = map.proj.inverse(
        map.projection.invert(
          [map.width / 2, map.height / 2])
      ).map(d3.format('.05f'))

    url = 'mailto:haihui@grep.ro?subject=Map%20note&body=' +
        encodeURIComponent('Location: ' + lngLat.join('/') + '\n\n\n')

    btn.attr('xlink:href', url)

  map.dispatch.on 'zoomend.note', ->
    render()

  map.dispatch.on 'redraw.note', ->
    render()
