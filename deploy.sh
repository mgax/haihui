#!/bin/bash

set -euo pipefail
rsync -rtv build/ marmota:qp/haihui/
