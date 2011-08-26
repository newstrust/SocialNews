logdir="/home/newstrust/stats/"
logfile="$logdir/json.access.$1.log"
grep '\.json' $logfile | grep -v gmodules | grep -v gclid | grep -v formats | grep -v newstrust.net | grep -v quick.com > /tmp/widget.accesses

echo "Total Monthly visits for JS Widgets (enter in widget pageviews column in spreadsheet): "
wc -l /tmp/widget.accesses

echo "Monthly Unique Visitors for JS Widgets (enter in widget visitors column in spreadsheet): "
cut -f1,7,12 -d" " /tmp/widget.accesses | sort | uniq | wc -l

cat /tmp/widget.accesses | visitors -R -O -B -Y -m 100 - -o html -f /data/newstrust/current/public/nt.widgets.report.nospam.$1.html
echo "open http://newstrust.net/nt.widgets.report.nospam.$1.html and note down # of unique visitors (enter in widget visits column in spreadsheet)" 

# Create a copy of the reports so that they are preserved
cp /data/newstrust/current/public/nt.widgets.report.nospam.$1.html /home/newstrust/stats
