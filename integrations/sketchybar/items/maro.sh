#!/bin/bash
# Source from sketchybarrc after PLUGIN_DIR is set. Does not replace other items.
"${MARO_PYTHON:-/usr/bin/python3}" "${MARO_PLUGIN:-$PLUGIN_DIR/maro.py}" register
