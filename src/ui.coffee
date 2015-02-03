width = 400
height = 400

svg = d3.select('body').append('svg')
    .attr('width', width)
    .attr('height', height)

geo = svg.append('g')

projection = d3.geo.albers()
    .center([0, 45.5])
    .rotate([-26, 0])
    .parallels([40, 50])
    .scale(s0 = 100000)
    .translate(t0 = [width / 2, height / 2])

zoom = d3.behavior.zoom()
    .scaleExtent([1, 1000])

path = d3.geo.path()
    .projection(projection)

svg.append('rect')
    .attr('class', 'zoomrect')
    .attr('width', width)
    .attr('height', width)
    .call(zoom)

d3.json 'build/ciucas.topojson', (error, map) ->
  if error then return console.error(error)

  segments = topojson.feature(map, map.objects.segments).features

  geo.selectAll('.way')
      .data(segments)
    .enter().append('path')
      .attr('class', 'way')
      .attr('d', path)

zoom.on 'zoom', ->
  tr = d3.event.translate; sc = d3.event.scale

  projection
      .scale(s0 * sc)
      .translate([t0[0] * sc + tr[0], t0[1] * sc + tr[1]])

  geo.selectAll('.way')
      .attr('d', path)
