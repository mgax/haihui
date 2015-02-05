Mountain guide, based on OSM data, displayed using D3.


## The plan

* Query [overpass](http://overpass-turbo.eu/), compile the data, generate a
  [TopoJSON](https://github.com/mbostock/topojson) data file. ✔
* Render a useful, zoomable map using d3
  * Hiking paths ✔
  * Points of interest ✔
  * Location marker
  * Elevation
* Plan a route by selecting contiguous segments
  * Interactive route editor
  * Route report (duration, elevation profile, directions)
* Package as mobile app using Cordova


## Setup

```shell
npm install
gulp data
gulp devel
```
