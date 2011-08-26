#!/bin/bash

# Make sure the script can be run from wherever by cd-ing to the dir. where the script is present
cd `dirname $0`/../public

# Remove root story listing cached files
rm -f stories.json stories.xml stories.js stories.rss
sleep 15

# legacy rss feeds
rm -rf rss
sleep 45
rm -rf RSS
sleep 45

# non-legacy rss feeds & json widgets
rm -rf stories
sleep 45
rm -rf topics
sleep 45
rm -rf subjects
sleep 45
rm -rf sources
sleep 45
rm -rf members
sleep 45
rm -rf feeds
sleep 45

# Remove all widget files (json & iframe .htm files) -- but, don't remove the symlink
cd widgets
rm -rf js/
# No need to get rid of iframe html files since they don't contain any data!
#rm -rf js/ subjects/ topics/ *.htm
