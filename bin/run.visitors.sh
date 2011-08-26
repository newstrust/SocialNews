logdir="."
logfile="$logdir/json.access.$1.log"
grep '\.json' $logfile | grep -v gmodules | grep -v gclid | grep -v formats | grep -v "Googlebot" | grep -v "Slurp" | grep -v discussions | grep -v bot | grep -v Alexa | grep -v taxonomy| grep -v newstrust.net > /tmp/widget.accesses

echo "----------------------------------------------"
echo "Total Monthly visits for JS Widgets (enter in widget pageviews column in spreadsheet): "
wc -l /tmp/widget.accesses

echo "Monthly Unique Visitors for JS Widgets (enter in widget visitors column in spreadsheet): "
cut -f2,6,8 -d"\"" /tmp/widget.accesses | sed 's/"/ /g;' |  sort | uniq | wc -l

echo "----- Pageviews by widget -----"
cut -f7 -d" " /tmp/widget.accesses | sort | uniq -c  | sort -nr | head -25

echo "----- Pageviews by referrer (top 25)[referrer = widget page host]  -----"
cut -f11 -d" " /tmp/widget.accesses | sort | uniq -c  | sort -nr | head -25

echo "----- Pageviews by widget & referrer (top 25) -----"
cut -f7,11 -d" " /tmp/widget.accesses | sort | uniq -c  | sort -nr | head -25

cat /tmp/widget.accesses | /home/capistrano/bin/visitors -R -O -B -Y -m 100 - -o html -f nt.widgets.report.$1.html
echo "Enter next number in widget visits column in spreadsheet"
grep 'Number of unique visitors' nt.widgets.report.$1.html
##echo "open nt.widgets.report.$1.html and note down # of unique visitors (enter in widget visits column in spreadsheet)" 
echo "open nt.widgets.report.$1.html for the full report" 
echo "----------------------------------------------"

logfile="$logdir/rss.access.$1.log"
echo "Total Monthly visits for RSS feeds (enter in feeds pageviews column in spreadsheet): "
wc -l $logfile

echo "Monthly Unique Visitors for RSS feeds (enter in feeds visitors column in spreadsheet): "
cut -f1,7,12 -d" " $logfile  | sort | uniq | wc -l

cat $logfile | /home/capistrano/bin/visitors -A -m 100 - -o html -f nt.rss.report.$1.html
echo "open nt.rss.report.$1.html and note down # of unique visitors (enter in feeds visits column in spreadsheet)" 

# compress logs
gzip $logdir/*.access.$1.log

