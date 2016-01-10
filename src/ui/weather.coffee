app.weather = (options) ->
  map = options.map
  button = options.button

  console.log("WEATHER DATA: BBOX IS")
  console.log map.db.bbox

  render = ->
    [lon, lat] = map.proj.inverse(
      map.projection.invert(
        [map.width / 2, map.height / 2])
    ).map(d3.format('.04f'))

    linkBase = "https://www.meteoblue.com/en/weather/forecast/week/"
    link = linkBase + "#{lat}N#{lon}E"
    button.attr('href', link)


  map.dispatch.on 'zoomend.note', ->
    render()

  map.dispatch.on 'redraw.note', ->
    render()