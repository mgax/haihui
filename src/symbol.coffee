app.symbol = {}

app.symbol.osmc = (src) ->
  bits = src.split(':')
  foreground = bits[2].split('_')
  sym = {
    waycolor: bits[0]
    background: bits[1]
    color: foreground[0]
    graphic: foreground[1]
  }

  return (selection) ->
    size = 12
    selection.attr('class', 'symbol-osmc')

    selection.append('rect')
        .attr('class', "background color-#{sym.background}")
        .attr('x', - size/2 - 1)
        .attr('y', - size/2 - 1)
        .attr('width', size + 1)
        .attr('height', size + 1)

    switch sym.graphic
      when 'stripe'
        selection.append('rect')
            .attr('class', "graphic color-#{sym.color}")
            .attr('x', - size / 6)
            .attr('y', - size / 2)
            .attr('width', size / 3)
            .attr('height', size)

      when 'dot'
        selection.append('circle')
            .attr('r', size  * .4)

      when 'cross'
        selection.append('rect')
            .attr('class', "graphic color-#{sym.color}")
            .attr('x', - size / 6)
            .attr('y', - size / 2)
            .attr('width', size / 3)
            .attr('height', size)

        selection.append('rect')
            .attr('class', "graphic color-#{sym.color}")
            .attr('x', - size / 2)
            .attr('y', - size / 6)
            .attr('width', size)
            .attr('height', size / 3)

      when 'triangle'
        r = size / 2
        selection.append('path')
            .attr('class', "graphic color-#{sym.color}")
            .attr('d', "M#{[0,-r]} L#{[-r,r]} L#{[r,r]} M#{[0,-r]}")


app.symbol.peak = (selection) ->
  selection.append('path')
      .attr('class', 'symbol-peak')
      .attr('d', "M0,-5 L5,3 L-5,3 L0,-5")


app.symbol.saddle = (selection) ->
  selection.append('path')
      .attr('class', 'symbol-saddle')
      .attr('d', "M0,2 L6,-2 L6,6 L-6,6 L-6,-2 L0,2")
