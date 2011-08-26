#!/bin/sh

# Dont try to preserve permissions and group info on receiver end since there is no correlation between the two
# Delete extraneous files on receiver end

# SSS: Dont --delete-after since we might keep moving servers and we wont have a copy of old logs files, etc. on the new servers.
#rsync -avz --no-p --no-g /home/newstrust/stats/ capistrano@media.newstrust.net:prod-stats/
rsync -avz --no-p --no-g /home/newstrust/newsletter.logs/ capistrano@media.newstrust.net:prod-newsletter.logs/
