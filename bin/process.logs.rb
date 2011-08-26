t    = Time.now-24*3600
year = t.year
mon  = t.month
day  = t.day

if Time.now.day == 1
  # change dir to home
  Dir.chdir("#{ENV['HOME']}")
  logdir = "/var/log/nginx"
  logdest = "nginx_logs" #"/data/newstrust/current/public"
  system "mkdir -p #{logdest}"
  mon = "0#{mon}" if mon < 10
  log = "access.#{mon}.log"
  (1 .. day).each { |d| 
    d = "0#{d}" if d < 10
    puts "date: #{d}"
      # Ignore requests from newstrust site itself! except when they are from iframe widgets -- in that case they are actually from an external site
    system "gunzip < #{logdir}/baltimore.access.log-#{year}#{mon}#{d}.gz | egrep \"\\.json|render_widget\" | egrep -v \"newstrust.net/([^w]|w[^i]|wi[^d])\" | egrep -v \"newstrust.net/widgets/preview\" >> #{logdest}/baltimore.json.#{log}"
    system "gunzip < #{logdir}/newstrust.access.log-#{year}#{mon}#{d}.gz | egrep \"\\.json|render_widget\" | egrep -v \"newstrust.net/([^w]|w[^i]|wi[^d])\" | egrep -v \"newstrust.net/widgets/preview\" >> #{logdest}/json.#{log}"
    system "gunzip < #{logdir}/newstrust.access.log-#{year}#{mon}#{d}.gz | egrep -i \"rss/\" | sed 's/\\/RSS/\\/rss/;' >> #{logdest}/rss.#{log}"
  }
  system "cd #{logdest}; gzip rss.#{log}; gzip json.#{log}; gzip baltimore.json.#{log}"
end
