.PHONY = all

HGTS := $(wildcard data/srtm-hgt/*.hgt)
TIFS := $(HGTS:data/srtm-hgt/%.hgt=data/srtm-tif/%.tif)

all: ${TIFS} data/srtm-tif/mosaic.vrt

data/srtm-tif/%.tif: data/srtm-hgt/%.hgt
	docker compose run --rm gdal gdal_translate /app/$< /app/$@

data/srtm-tif/mosaic.vrt: ${TIFS}
	docker compose run --rm gdal gdalbuildvrt data/srtm-tif/mosaic.vrt $(TIFS)
