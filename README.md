Download the data:

```sh
mkdir -p data
curl 'http://overpass-api.de/api/interpreter?data=%5Bout%3Ajson%5D%5Btimeout%3A25%5D%3B(relation%5B%22route%22%3D%22hiking%22%5D(45.4371%2C25.8449%2C45.5619%2C26.0518)%3B)%3Bout%20body%3B%3E%3Bout%20skel%20qt%3B' > data/ciucas.geojson
```
