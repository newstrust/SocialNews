#!/bin/bash

# Make sure the script can be run from wherever by cd-ing to the dir. where the script is present
cd `dirname $0`/../tmp/cache

# Remove views directory from the fragment cache
rm -rf views
