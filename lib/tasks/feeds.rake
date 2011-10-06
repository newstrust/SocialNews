namespace :socialnews do
  namespace :feeds do
    def remove_pending_tasks_with_tag(tag)
      Bj.table.job.find(:all, :conditions => {:tag => tag, :state => "pending"}).each { |j| j.destroy }
    end

#    desc "DEPRECATED: Auto fetch all (auto-fetchable) feeds!"
#    task(:autofetch_all => :environment) do
#      puts "Fetching all feeds"
#
#      require 'lib/feed_fetcher'
#      fetch_log = FeedFetcher.autofetch_feeds
#      Mailer.deliver_feed_fetch_log(fetch_log)
#    end
#
#    desc "DEPRECATED: Fetch all feeds, and submit this task to Bj so that the feed fetcher runs periodically!"
#    task(:fetch_and_submit => :environment) do
#      if RAILS_ENV != 'production'
#        puts "No auto feed fetching in non-production environments!"
#        return
#      end
#
#      ## Record next submission time before we start anything
#      new_time         = Time.now + SocialNewsConfig["bj"]["task_periods"]["feed_fetcher"].minutes
#      approx_task_time = SocialNewsConfig["bj"]["approx_execution_times"]["feed_fetcher"].minutes
#      expected_finish  = new_time + approx_task_time
#
#      ## Check when the next newsletter is scheduled -- don't schedule a feed fetcher too close to that task
#      too_close = false
#      Bj.table.job.find(:all, :conditions => {:tag => ["newsletter_daily", "newsletter_weekly"], :state => "pending"}).each { |j|
#        too_close = true if (new_time <= j.submitted_at) && (expected_finish >= j.submitted_at)
#      }
#
#      # Push back the scheduling if too_close
#      new_time = expected_finish + approx_task_time if too_close
#
#      ## Destroy pending feed fetcher jobs -- ensure that there is exactly one pending feed fetcher job at all times!
#      remove_pending_tasks_with_tag("feed_fetcher")
#
#      ## Run the feed fetcher code now -- but trap exceptions!
#      begin
#        Rake::Task["socialnews:feeds:autofetch_all"].invoke
#      rescue Exception => e
#        msg = "Feed Fetcher -- got exception '#{e}'. It has been resubmitted to run again at #{new_time}.  Backtrace follows:\n\n#{e.backtrace.inspect}"
#        RAILS_DEFAULT_LOGGER.error "Feed Fetcher: Got exception #{e}; #{e.backtrace.inspect}"
#        Mailer.deliver_generic_email({:recipients => SocialNewsConfig["rake_errors_alert_recipient"], :subject => "Feed Fetcher Exception", :body => msg})
#      end
#
#      ## Re-submit this task for execution (at a future time)
#      Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:fetch_and_submit", :submitted_at => new_time, :tag => "feed_fetcher", :priority => SocialNewsConfig["bj"]["priorities"]["feed_fetcher"]
#    end

    desc "DEPRECATED: Stop feed fetching!"
    task(:stop_fetching => :environment) do
      remove_pending_tasks_with_tag("feed_fetcher")
    end

    desc "Fetch a specific feed"
    task(:fetch_feed => :environment) do
      unless ENV.include?("feed_id")
        raise "usage: rake [RAILS_ENV=env_here] fetch_feed feed_id=FEED_ID [submitter_id=YOUR_MEMBER_ID] ## The arguments in [ ] are optional"
      end

        # Parse parameters
      feed_id = ENV["feed_id"]
      submitter_id = ENV["submitter_id"]
      if submitter_id
        begin
          submitter = Member.find(submitter_id)
        rescue Exception => e
          RAILS_DEFAULT_LOGGER.error "Exception fetching feed fetch requesting member; id is #{submitter_id}; #{e}"
        end
      end

      begin
          ## Fetch feed
        f = Feed.find(feed_id)
        f.fetch

          ## I wish I didn't have to set up the conditions like this, but if I pass in value-pairs in an array, AR doesn't like the % chars!
        bj_job = Bj.table.job.find(:first, :conditions => "state = 'running' AND command like '%fetch_feed feed_id=#{feed_id}" + (submitter.nil? ? "" : " submitter_id=#{submitter.id}") + "%'", :order => "bj_job_id desc")

          ## Update feed information
        f.last_fetched_at = Time.now
        f.last_fetched_by = submitter.nil? ? Member.nt_bot.id : submitter.id
        f.save!

          ## Send out fetch confirmation email if a member requested a fetch
        if submitter
          if f.is_fb_user_newsfeed?
            Mailer.deliver_fb_newsfeed_fetch_success_email(feed_id, submitter)
          elsif f.is_twitter_user_newsfeed?
            Mailer.deliver_twitter_newsfeed_fetch_success_email(feed_id, submitter)
          else 
            Mailer.deliver_feed_fetch_success_email(feed_id, bj_job, submitter.email) 
          end
        end
      rescue Exception => e
        msg = "Got exception #{e} fetching feed with id #{feed_id}; Backtrace follows:\n#{e.backtrace.inspect}"
        RAILS_DEFAULT_LOGGER.error "Exception fetching feed #{feed_id}; #{e}; #{e.backtrace.inspect}"
        Mailer.deliver_generic_email({:recipients => SocialNewsConfig["rake_errors_alert_recipient"], :subject => "FEED Fetch Exception", :body => msg})
        if submitter
          if f.is_fb_user_newsfeed?
            msg = "We are sorry!  There was an error fetching your facebook newsfeed.  The error has been logged and we are looking into it."
            subj = "Facebook Feed Fetch Results"
          else
            msg = "There was an error fetching the feed you requested.  An email has been sent to #{SocialNewsConfig["rake_errors_alert_recipient"]}."
            subj = "FEED Fetch Error!"
          end
          Mailer.deliver_generic_email({:recipients => submitter.email, :subject => subj, :body => msg})
        end
      end
    end

    def emit_db_initialization_code(fh)
      server  = APP_DEFAULT_URL_OPTIONS[:host]
      port    = APP_DEFAULT_URL_OPTIONS[:port]
      server += ":#{port}" if !port.blank?
      dbconf  = Rails::Configuration.new.database_configuration[RAILS_ENV]
      buf = <<-eof
require 'rubygems'
require 'lib/feed_parser'
fp = FeedParser.new({:rails_env => '#{RAILS_ENV}', :server_url => 'http://#{server}', :mysql_server => '#{dbconf["host"]}', :mysql_user => '#{dbconf["username"]}', :mysql_password => '#{dbconf["password"]}', :mysql_db => '#{dbconf["database"]}'})
      eof
      fh.write(buf)
    end

    def start_new_script(i, spawner)
      outdir  = "#{RAILS_ROOT}/lib/tasks"
      script  = "#{outdir}/fetch_feeds.#{i}.rb"
      puts "Generating script #{script}"
      fh = File.open(script, "w")
      emit_db_initialization_code(fh)
      spawner.write("ruby #{script} > #{outdir}/fetch.#{i}.out 2> #{outdir}/fetch.#{i}.err &\n")
      return fh
    end

    # Generate the feed fetcher scripts and the spawner task
    desc "Generate fetcher scripts"
    task(:gen_fetchers => :environment) do
      unless ENV.include?("num_fetchers")
        raise "usage: rake [RAILS_ENV=env_here] socialnews:feeds:gen_fetchers num_fetchers=INTEGER_HERE  # number of parallel fetchers you want"
      end

      spawner_script_path = "#{RAILS_ROOT}/lib/tasks/spawn_feed_fetchers.sh"
      spawner      = File.open(spawner_script_path, "w")
      spawner.write("#!/bin/sh\n\n")
      feeds        = Feed.find(:all, :select => "id", :conditions => "auto_fetch = true").sort { |a,b| n = rand(10); n == 5 ? 0 : (n < 5 ? -1 : 1) }.map(&:id)
      num_feeds    = feeds.length
      num_fetchers = ENV["num_fetchers"].to_i
      n_per_script = num_feeds / num_fetchers
      diff         = num_feeds - num_fetchers * n_per_script
      script_index = 0
      fh           = start_new_script(script_index, spawner)
      i            = 0
      num_ignored  = 0
      feeds.each { |f_id|
        f = Feed.find(f_id)

        next if f.is_fb_user_newsfeed?

# FB feed fetcher code is old and needs upgrading.
#
#        # Check if fb permissions have expired
#        if f.is_fb_user_newsfeed?
#          m = Member.find(f.member_profile_id)
#          if m.follows_fb_newsfeed? && !m.can_follow_fb_newsfeed?
#            puts "Ignoring #{m.name}'s facebook feed #{f_id} since permissions have expired!"
#            num_ignored += 1
#            next
#          end
#        end

        fh.write "fp.fetch_and_parse({:id => #{f.id}, :url => '#{f.url}'})\n"
        i += 1
        if (i > n_per_script) || (i == n_per_script && script_index >= diff)  # lets you let some scripts fetch 1 more feed than others 
          # Close the previous script and open a new one
          script_index += 1
          fh.write "fp.shutdown\n"
          if (script_index < num_fetchers)
            fh.close
            fh = start_new_script(script_index, spawner) 
            i = 0
          end
        end
      }
      fh.write "fp.shutdown\n"
      fh.close

      # After the spawner spawns all the feed fetchers, ask it to sleep for 5 minutes right away.
      # Then, block till all feeds are fetched, and once done, run the rake task to process the fetched stories.
      # But, only block for 60 minutes at the most -- in case some feed fetcher update posted to the server got lost!
      server  = APP_DEFAULT_URL_OPTIONS[:host]
      port    = APP_DEFAULT_URL_OPTIONS[:port]
      server += ":#{port}" if !port.blank?
      poller = "require 'lib/feed_parser'; fp = FeedParser.new({:server_url => 'http://#{server}', :no_dbc => true}); m = 0; while (fp.num_completed_feeds < #{num_feeds - num_ignored}) && (m < 60) do; sleep(60); m += 1; end; fp.shutdown"
      newbuf = <<-eof
sleep 300
ruby -e "#{poller}"
rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:process_auto_fetched_stories
      eof
      spawner.write(newbuf)
      spawner.close
    end

    # Generate the feed fetcher scripts and the spawner task
    desc "Start parallel fetch"
    task(:start_parallel_fetch => :environment) do
      if RAILS_ENV != 'production'
        puts "No auto feed fetching in non-production environments!"
      else
        # 1. Record next feed fetcher time before we start anything
        new_time         = Time.now + SocialNewsConfig["bj"]["task_periods"]["feed_fetcher"].minutes
        approx_task_time = SocialNewsConfig["bj"]["approx_execution_times"]["feed_fetcher"].minutes
        expected_finish  = new_time + approx_task_time

        # 2. Check when the next newsletter is scheduled -- don't schedule a feed fetcher too close to that task
        too_close = false
        nl_tags = (Newsletter::VALID_NEWSLETTER_TYPES - [Newsletter::MYNEWS]).collect { |t| "newsletter_#{t}" }
        Bj.table.job.find(:all, :conditions => {:tag => nl_tags, :state => "pending"}).each { |j|
          too_close = true if (new_time <= j.submitted_at) && (expected_finish >= j.submitted_at)
        }

        # 3. Push back the scheduling if too_close
        new_time = expected_finish + approx_task_time if too_close

        # 4. Run the spawner
        begin
          ENV["num_fetchers"] = SocialNewsConfig["feed_fetcher"]["num_fetchers"].to_s
          Rake::Task["socialnews:feeds:gen_fetchers"].invoke

          # Delete any pending spawner tasks (no multiple active spawners)
          remove_pending_tasks_with_tag("ff_spawner")

          # Rather than executing the spawner in this rake task, submit the shell script as a new bj job!
          # This ensures that the current rake tasks that loads the entire rails environment completes quickly
          # and frees up all that memory!  The spawner and all associated fetcher scripts run as ordinary
          # shell / ruby scripts and consume far less memory.
          spawner_script_path = "#{RAILS_ROOT}/lib/tasks/spawn_feed_fetchers.sh"
          Bj.submit "/bin/sh #{spawner_script_path}", :submitted_at => Time.now, :tag => "ff_spawner", :priority => SocialNewsConfig["bj"]["priorities"]["feed_fetcher"]
        rescue Exception => e
          msg = "Feed Fetcher -- got exception '#{e}'. It has been resubmitted to run again at #{new_time}.  Backtrace follows:\n\n#{e.backtrace.inspect}"
          RAILS_DEFAULT_LOGGER.error "Feed Fetcher: Got exception #{e}; #{e.backtrace.inspect}"
          Mailer.deliver_generic_email({:recipients => SocialNewsConfig["rake_errors_alert_recipient"], :subject => "Feed Fetcher Exception", :body => msg})
        end

        # 5. Submit the next round of autofetch rake tasks to the BJ processor
        # Delete any pending spawner tasks (no multiple active spawners)
        remove_pending_tasks_with_tag("parallel_fetch")
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:start_parallel_fetch", :submitted_at => new_time, :tag => "parallel_fetch", :priority => SocialNewsConfig["bj"]["priorities"]["feed_fetcher"]
      end
    end

    # NOTE: We are still tightly controlling how the feed fetcher runs.  While we could let the
    # feed fetchers and story processors run independently on their own schedules, for now,
    # we are still waiting till all feeds are done fetching and then run the story processors
    # serially.  Only after all that is done, do we queue the next round of fetching!  This is just
    # so we have a tight leash on resource usage -- so that at any point of time, at most one copy
    # of the fetchers or the processors are running.
    desc "Processed auto-fetched stories"
    task(:process_auto_fetched_stories => :environment) do
      # 1. Get all the feed fetch status from the db and extract fetch errors
      failed_fetches = []
      fetch_status   = PersistentKeyValuePair.find(:all, :conditions => ["persistent_key_value_pairs.key like ?", "feed.%.status"])
      num_feeds      = fetch_status.length
      fetch_status.each { |pk|
        begin
          if !pk.value.blank?
            feed_id = $1 if pk.key =~ /feed.(\d+).status/
            f = Feed.find(feed_id)
            feed_name = f.name
            failed_fetches << [feed_id, feed_name, pk.value]
            if f.is_fb_user_newsfeed? && !f.can_read_fb_newsfeed? 
              f.mark_fb_newsfeed_unreadable # Turn off fetch for fb user news feed!
            elsif f.is_twitter_user_newsfeed? && pk.value =~ /Unauthorized/
              f.update_attribute(:auto_fetch, false) # Turn off auto-fetch
            end
          end
        rescue Exception => e
          puts "Error generating feed log: #{e}"
        ensure
          # Get rid of the feed fetch status entry from the db so that next round of fetches start with a clean slate
          pk.destroy
        end
      }

      begin
        # 2. Process all fetched stories and compute autolist scores
        queued_stories = FeedFetcher.process_fetched_stories

        # 3. Deliver the fetch log
        Mailer.deliver_feed_fetch_log({ :num_feeds => num_feeds, :failed_fetches => failed_fetches, :queued_stories => queued_stories })
      rescue Exception => e
        msg = "Process Auto Fetched Stories -- got exception '#{e}'.  Backtrace follows:\n\n#{e.backtrace.inspect}"
        RAILS_DEFAULT_LOGGER.error "Process Auto Fetched Stories: Got exception #{e}; #{e.backtrace.inspect}"
        Mailer.deliver_generic_email({:recipients => SocialNewsConfig["rake_errors_alert_recipient"], :subject => "Process Auto Fetched Stories Exception", :body => msg})
      end
    end
  end
end
