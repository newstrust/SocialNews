#!/bin/sh

# The following doesn't work when absolute paths are used to invoke the script
#
#home=`pwd`/`dirname $0`/../..
#home=/home/subbu/newstrust/site/rails/trunk

rails_env=$1; shift
task=$1; shift
home=/data/newstrust/current; cd $home
outfile=`echo $task | sed 's/:/-/g;'`.`date +"%Y-%m-%d"`.out
touch log/$outfile
echo "------- Starting run of rake task at `date` ----------" >> log/$outfile
rake $rails_env $task $* >> log/$outfile
echo "------- Ended    run of rake task at `date` ----------\n" >> log/$outfile
