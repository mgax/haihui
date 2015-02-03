width = 400
height = 400

svg = d3.select('body').append('svg')
    .attr('width', width)
    .attr('height', height)

projection = d3.geo.albers()
    .center([0, 45.5])
    .rotate([-26, 0])
    .parallels([40, 50])
    .scale(100000)
    .translate([width / 2, height / 2])

path = d3.geo.path()
    .projection(projection)

d3.json 'data/ciucas.topojson', (error, map) ->
  if error then return console.error(error)

  segments = topojson.feature(map, map.objects.segments).features

  svg.append('g')
    .selectAll('.way')
      .data(segments)
    .enter().append('path')
      .attr('class', 'way')
      .attr('d', path)
