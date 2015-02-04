s0 = 100000
sc = 1
t0 = [0, 9]
tr = [0, 0]

svg = d3.select('body').append('svg')

geo = svg.append('g')

projection = d3.geo.albers()
    .center([0, 45.5])
    .rotate([-26, 0])
    .parallels([40, 50])
    .scale(s0)
    .translate(t0)

zoom = d3.behavior.zoom()
    .scaleExtent([1, 1000])

path = d3.geo.path()
    .projection(projection)

svg.append('rect')
    .attr('class', 'zoomrect')
    .call(zoom)

renderGeo = ->
  projection
      .scale(s0 * sc)
      .translate([t0[0] * sc + tr[0], t0[1] * sc + tr[1]])

  geo.selectAll('.way')
      .attr('d', path)

resize = ->
  width = parseInt(d3.select('body').style('width'))
  height = parseInt(d3.select('body').style('height'))

  svg.select('.zoomrect')
      .attr('width', width)
      .attr('height', height)

  projection.translate(t0 = [width / 2, height / 2])

  renderGeo()

d3.select(window).on('resize', resize)
resize()

d3.json 'build/ciucas.topojson', (error, map) ->
  if error then return console.error(error)

  segments = topojson.feature(map, map.objects.segments).features

  geo.selectAll('.way')
      .data(segments)
    .enter().append('path')
      .attr('class', 'way')

  renderGeo()

zoom.on 'zoom', ->
  tr = d3.event.translate
  sc = d3.event.scale
  renderGeo()
