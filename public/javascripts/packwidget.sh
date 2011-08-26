#!/bin/sh

java -jar ~/software/yuicompressor-2.3.5/build/yuicompressor-2.3.5.jar render_widget.uncompressed.js | perl compress.js.pl > /tmp/render_widget.js
