namespace :socialnews do
  desc "Refresh aggregate statistics"
  task :refresh_stats => :environment do
    # To spread around the db load:
    # * Dont recompute more than 500 aggregate stats at each time for each model
    AggregateStatistic::STATISTICS.each { |s|
      begin
        stats = AggregateStatistic.find(:all, :conditions => ["model_type = ? AND statistic = ? AND updated_at < ?", s[:model_type], s[:name], Time.now - s[:max_age]], :limit => 500, :order => "updated_at ASC")
        stats.each { |s| s.refresh } if !stats.blank?
      rescue Exception => e
        RAILS_DEFAULT_LOGGER.error "Exception '#{e}' processing stat #{s.inspect}: BT: #{e.backtrace.inspect}"
      end
      # sleep 5 seconds after each stat type
      sleep(5)
	  }
  end
end
