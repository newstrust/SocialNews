#!/bin/sh

# Dont try to preserve permissions and group info on receiver end since there is no correlation between the two
# Delete extraneous files on receiver end

# SSS: Nothing to do right now since they are all on Amazon S3
# rsync -avz --no-p --no-g --delete-after /data/newstrust/shared/photos/ capistrano@media.newstrust.net:images/
