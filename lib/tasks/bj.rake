namespace :socialnews do
  namespace :bj do
    desc "Start BJ"
    task(:start => :environment) do
        # Delete stale jobs we don't want persisting between server restarts/deploys
      pending_jobs = Bj.table.job.find(:all, :conditions => {:tag => ["feed_fetcher", "ratings", "startup", "mynews"], :state => "pending"})
      pending_jobs.each { |j| j.destroy }

        # Fetch daily, weekly, and mynews newsletters so that if they don't exist, they get initialized
      Newsletter::VALID_NEWSLETTER_TYPES.each { |freq| Newsletter.fetch_latest_newsletter(freq, Member.nt_bot) }

        # Submit the starter rake jobs
      Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:ratings:update_and_submit", :submitted_at => Time.now + 2.minutes, :tag => "startup"

        # Startup autofetch task
      Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:start_parallel_fetch", :submitted_at => Time.now + 1.minutes, :tag => "startup"
    end

    desc "Stop BJ"
    task(:stop => :environment) do
      puts "Killing BJ .."
      abcs = ActiveRecord::Base.configurations # for db credentials
      mysql_command = "mysql --user=#{abcs[RAILS_ENV]['username']} --password=#{abcs[RAILS_ENV]['password']} " + 
                      "--host=#{abcs[RAILS_ENV]['host']} #{abcs[RAILS_ENV]['database']}"
      cmd  = "select value from bj_config where bj_config.key=\'#{RAILS_ENV}.0.pid\';"
      res = `echo \"#{cmd}\" | #{mysql_command}`
      pid = $1 if res && res =~ /.*?(\d+).*/
      `kill -9 #{pid}` if (pid)
    end
  end
end
