#!/usr/bin/env python

import sys
import ogr

geom_in = ogr.CreateGeometryFromJson(sys.stdin.read())
geom_out = geom_in.Buffer(0)
sys.stdout.write(geom_out.ExportToJson())
