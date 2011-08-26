namespace :socialnews do
  namespace :stories do
    desc "Generate mysql script to decay story activity score"
    task(:gen_decay_script => :environment) do
      outdir = "#{RAILS_ROOT}/lib/tasks"
      script = "#{outdir}/decay_activity_score.rb"
      puts "Generating script #{script}"
      fh = File.open(script, "w")
      dbconf = Rails::Configuration.new.database_configuration[RAILS_ENV]

# Here is the logic!
#
# We divide the day in 4 zones:
#  5 am PT -  7 pm PT -- zone 1  -- Peak activity
#  4 am PT -  5 am PT -- zone 2  -- Early birds  (half-peak)
#  7 pm PT - 10 pm PT -- zone 3  -- Night owls   (half-peak)
# 10 pm PT -  4 am PT -- zone 4  -- Zzzz ....    (quarter-peak)
#
# Zone 1 is 'peak activity zone' and we decay scores normally
# Zones 2 & 3 are lower activity, and we decay scores by 2/3 times the value of the peak
# Zone 4 is lowest activity, and we decay scores by 1/3 the value of the peak
#
# The idea behind this is to not penalize stories that were submitted in low activity periods and give them a chance to be seen by members
# We decay them at slower rates

      buf = <<-eof
v = #{ActivityScore::DECAY_FACTOR}.to_f
h = Time.now.hour - 4
x = 1 + (h < 1 ? v/1.5 : (h < 15 ? v : (h < 18 ? v/1.5 : v/3))) / 100
system("echo 'update stories set activity_score = activity_score / \#{x} where activity_score >= 5' | mysql --host=#{dbconf["host"]} --user=#{dbconf["username"]} --password=#{dbconf["password"]} #{dbconf["database"]}")
eof
      fh.write(buf)
      fh.close
    end
  end
end
