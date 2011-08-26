logdir="."
logfile="$logdir/baltimore.json.access.$1.log"
grep '\.json' $logfile | grep -v gmodules | grep -v gclid | grep -v formats | grep -v "Googlebot" | grep -v "Slurp" | grep -v discussions | grep -v bot | grep -v Alexa | grep -v taxonomy| grep -v newstrust.net > /tmp/balt.widget.accesses

echo "----- Aggregate stats -----"
echo "Total Monthly visits for JS Widgets (enter in widget pageviews column in spreadsheet): "
wc -l /tmp/balt.widget.accesses

echo "Monthly Unique Visitors for JS Widgets (enter in widget visitors column in spreadsheet): "
cut -f2,6,8 -d"\"" /tmp/balt.widget.accesses | sed 's/"/ /g;' |  sort | uniq | wc -l

echo "----- Pageviews by widget -----"
cut -f7 -d" " /tmp/balt.widget.accesses | sort | uniq -c  | sort -nr

echo "----- Pageviews by referrer (top 25)[referrer = widget page host]  -----"
cut -f11 -d" " /tmp/balt.widget.accesses | sort | uniq -c  | sort -nr | head -25

echo "----- Pageviews by widget & referrer (top 25) -----"
cut -f7,11 -d" " /tmp/balt.widget.accesses | sort | uniq -c  | sort -nr | head -25

cat /tmp/balt.widget.accesses | /home/capistrano/bin/visitors -R -O -B -Y -m 100 - -o html -f balt.widgets.report.$1.html
echo "Enter next number in widget visits column in spreadsheet"
grep 'Number of unique visitors' balt.widgets.report.$1.html
##echo "open balt.widgets.report.$1.html and note down # of unique visitors (enter in widget visits column in spreadsheet)"
echo "open balt.widgets.report.$1.html for the full report"
echo "----------------------------------------------"

# compress logs
gzip $logdir/*.access.$1.log
