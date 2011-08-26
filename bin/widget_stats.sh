raw data: egrep "\.json|render_widget" /var/log/nginx/baltimore.access.log | cut -f2,4,8 -d"\"" | sed 's/"/ /g;' | cut -f2,4,5 -d" "
