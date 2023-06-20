# haihui

Collection of hiking maps, optimized for mobile use, based on OSM data.

![screenshot](https://raw.githubusercontent.com/mgax/haihui/master/media/screenshot.jpg)

## Setup

```shell
npm install
gulp
gulp devel
```

### Ubuntu tips

```shell
sudo apt-get install python-gdal gdal-bin
npm install -g topojson
```

### DEM
* Create a directory named `./data/`.
* Download tiles from https://earthexplorer.usgs.gov/, from the [SRTMGL1v003](https://lpdaac.usgs.gov/products/srtmgl1v003/) dataset. They come as `.hgt.zip` files. Unarchive the files and place the `.hgt` files under `./data/srtm-hgt/`.
* Run `make` to convert the files to `tif` and create a mosaic file.
* Create a folder named `./data/contours/`.

Create map for specific region, eg. for Piatra Craiului (crai):

```shell
gulp data-crai # "crai" is the region name
```

## How it works

For each region, we query [Overpass](http://overpass-api.de), filter the
results, and convert them to
[TopoJSON](https://github.com/mbostock/topojson/wiki). Elevation
contours are from
[SRTM](https://en.wikipedia.org/wiki/Shuttle_Radar_Topography_Mission).
We then package all data for a region as JSON, the largest is almost
1MB, and they compress to ~30% of the original size with gzip. In the
browser, we save the data in
[appcache](https://en.wikipedia.org/wiki/Cache_manifest_in_HTML5), and
render the map as
[SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), using
[D3.js](http://d3js.org) and lots of creativity :)


## License

Code is licensed as MIT. Data is © [OpenStreetMap
contributors](http://www.openstreetmap.org/copyright), except for
contour lines, which come from NASA's SRTM dataset.
