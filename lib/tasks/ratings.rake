namespace :socialnews do
  namespace :ratings do
    def remove_rating_tasks
      Bj.table.job.find(:all, :conditions => {:tag => "ratings", :state => "pending"}).each { |j| j.destroy }
    end

    desc "Update ratings now by processing pending processable objects"
    task(:update => :environment) do
      [MetaReview, SourceReview, Review, Member, Story, Source, SourceStats].each { |pj_type|
          # Limit to 2000 objects per round -- hack to get around time and memory constraints
          #
          # This task leaks memory and by limiting how long it runs, we can limit memory hogging
          # The other objects can be processed in subsequent runs of this task
          # This is mainly relevant for full recalcs (member, source, etc.)
          #
          # Load only the 'id' field for 2 reasons:
          # 1. this reduces memory footprint of the 2000-element array
          # 2. we aren't holding live refs. to all the processed jobs since a processed job refers to an entire
          #    tree of nested associations ... so, we will be carrying around that baggage till the end of this task.
        jobs = ProcessJob.find_all_by_processable_type(pj_type.to_s, :select => "id", :limit => 2000)
        next if jobs.nil?

        jobs.each { |pj_id|
          pj = ProcessJob.find(pj_id)
          processed = pj.process
          pj.destroy

          # for sources, update sort-ratings for all its unrated stories, and update aggregate info
          pj.processable.update_sort_ratings_for_unrated_stories if processed && (pj_type == Source)
        }
      }
    end

    desc "Update ratings, and submit this task to Bj so that the ratings processor runs periodically!"
    task(:update_and_submit => :environment) do
        # Record next submission time before we start anything
      new_time         = Time.now + SocialNewsConfig["bj"]["task_periods"]["ratings_processor"].minutes
      approx_task_time = SocialNewsConfig["bj"]["approx_execution_times"]["ratings_processor"].minutes
      expected_finish  = new_time + approx_task_time

        # Check when the next newsletter is scheduled -- don't schedule a rating update task too close to that task
      too_close = false
      nl_tags = (Newsletter::VALID_NEWSLETTER_TYPES - [Newsletter::MYNEWS]).collect { |t| "newsletter_#{t}" }
      Bj.table.job.find(:all, :conditions => {:tag => nl_tags, :state => "pending"}).each { |j|
        too_close = true if (new_time <= j.submitted_at) && (expected_finish >= j.submitted_at)
      }

        # Push back the scheduling ...
      new_time = expected_finish + approx_task_time if too_close

        # Remove any pending rating tasks (we only want one pending task in the table at any point)
      remove_rating_tasks

        # Run the ratings processor now -- but trap any exceptions!
      begin
        Rake::Task["socialnews:ratings:update"].invoke
      rescue Exception => e
        msg = "Caught exception #{e} running the rating update task! BT: #{e.backtrace * '\n'}"
        puts "Caught exception #{e} running the rating update task!"
        FeedFetcher.logger.error "RATING TASK: Caught exception #{e} running the rating update task! BT: #{e.backtrace * '\n'}"
        Mailer.deliver_generic_email(:recipients => SocialNewsConfig["rake_errors_alert_recipient"], :subject => "Rating Update task exception", :body => msg)
      end

        # Re-submit this task for execution (at a future time)
      Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:ratings:update_and_submit", :submitted_at => new_time, :tag => "ratings", :priority => SocialNewsConfig["bj"]["priorities"]["ratings_processor"]
    end

    desc "Remove all rating processor tasks!"
    task(:stop => :environment) do
      remove_rating_tasks
    end

# SSS: Not relevant any more -- superseded by aggregate statistics!
#
#    desc "Update aggregate info for all listed sources -- run this once a week!"
#    task(:update_aggregate_source_info => :environment) do
#      Source.find(:all, :conditions => ["status='list'"], :select => "id").each { |s|
#        begin
#          s = Source.find(s.id)
#          puts "Processing source #{s.id} @ #{Time.now.strftime("%H:%M:%S")}: #{s.name}"
#          s.initialize_aggregate_info
#        rescue Exception => e
#          puts "While processing source #{s.id}, caught exception #{e}; Backtrace:\n #{e.backtrace.inspect}"
#        end
#      }
#    end

    desc "Submit all sources for recalc"
    task(:recalc_all_sources => :environment) do
      #Source.find(:all, :select => "id").each { |s| s.process_in_background }
      Source.connection.execute("insert into process_jobs(processable_id, processable_type) (select sources.id, 'Source' from sources)");
    end

    desc "Submit all reviews for recalc"
    task(:recalc_all_reviews => :environment) do
      #Review.find(:all, :select => "id").each { |r| r.process_in_background }
      Review.connection.execute("insert into process_jobs(processable_id, processable_type) (select reviews.id, 'Review' from reviews)");
    end

    desc "Submit all stories for recalc"
    task(:recalc_all_stories => :environment) do
      #Story.find(:all, :select => "id").each { |s| s.process_in_background }
      Story.connection.execute("insert into process_jobs(processable_id, processable_type) (select stories.id, 'Story' from stories)");
    end

    desc "Submit all members for recalc"
    task(:recalc_all_members => :environment) do
      #Member.find(:all, :select => "id").each { |m| m.process_in_background }
      Member.connection.execute("insert into process_jobs(processable_id, processable_type) (select members.id, 'Member' from members)");
    end

    desc "Find Top Sources in last year"
    task(:years_top_sources => :environment) do
      top_sources = {}
      num_sources = 20
      time_threshold = Time.now - 365.days

      # From Fab: Ignore Consortium News, Media is a Plural, The Writing Corner
      sources_to_ignore = Source.find_all_by_slug(["consortium_news", "media_is_a_plural", "writing_corner"]).map(&:id)

      # Overall msm and ind
      rated_story_thresholds = Source::RATED_STORY_THRESHOLDS[:overall]
      stmt = "select * from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.created_at >= ? and sources.ownership=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
      puts "------------------------------------------------------"
      puts "Overall Top Sources (msm/ind)"
      puts "------------------------------------------------------"
      [:msm, :ind].each { |ownership|
        query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], time_threshold, ownership.to_s, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[ownership]*3.3).round, sources_to_ignore, rated_story_thresholds[ownership], num_sources ])
        top_sources[ownership] = Source.connection.select_all(query)
        puts "Top Sources (#{ownership.to_s})\n\t#{top_sources[ownership].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t"}"
      }

      # Overall by msm_news, msm_opinion, ind_news, ind_opinion
      puts "------------------------------------------------------"
      puts "Overall Top Sources (split by msm/ind, news/opinion)"
      puts "------------------------------------------------------"
      rated_story_thresholds = Source::RATED_STORY_THRESHOLDS[:overall]
      stmt = "select * from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.stype_code=? and stories.created_at >= ? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
      puts "Overall Top Sources"
      [:msm_news, :msm_opinion, :ind_news, :ind_opinion].each { |stype|
        query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], eval("Story::#{stype.to_s.upcase}"), time_threshold, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[stype]*3.3).round, sources_to_ignore, rated_story_thresholds[stype], num_sources ])
        top_sources[stype] = Source.connection.select_all(query)
        puts "Top Sources(#{stype.to_s})\n\t#{top_sources[stype].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t" }"
      }

      # By subjects
      puts "------------------------------------------------------"
      puts "Overall Top Sources (by subject)"
      puts "------------------------------------------------------"
      ["us", "world", "politics", "scitech", "business", "media"].each { |slug|
        subj = Subject.find_subject(slug)
        top_sources[slug] = Source.top_sources_for_subject(subj, num_sources)
        puts "Top Sources for #{subj.name}"
        [:msm_news, :msm_opinion, :ind_news, :ind_opinion, :msm, :ind].each { |stype|
           puts "(#{stype.to_s})\n\t#{top_sources[slug][stype].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t" }"
        }
        puts "\n\n"
      }

      # By topics
      puts "------------------------------------------------------"
      puts "Overall Top Sources (by topic)"
      puts "------------------------------------------------------"
      ["afghanistan", "climate_change", "environment", "health_care", "barack_obama", "us_economy", "us_congress", "finance", "gay_lesbian"].each { |slug|
        topic = Topic.find_topic(slug)
        top_sources[slug] = Source.top_sources_for_topic(topic, num_sources)
        puts "Top Sources for #{topic.name}"
        [:msm_news, :msm_opinion, :ind_news, :ind_opinion, :msm, :ind].each { |stype|
           puts "(#{stype.to_s})\n\t#{top_sources[slug][stype].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t" }"
        }
        puts "\n\n"
      }

      # By publication type
      puts "------------------------------------------------------"
      puts "Overall Top Sources (by publication type and source ownership)"
      puts "------------------------------------------------------"
      rated_story_thresholds = Source::RATED_STORY_THRESHOLDS[:publication]
      stmt = "select * from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories,source_media where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.created_at >= ? and source_media.source_id=sources.id and source_media.main=1 and source_media.medium=? and sources.ownership=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
      ["newspaper", "magazine"].each { |ptype|
        top_sources[ptype] = {}
        [:msm, :ind].each { |ownership|
          query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], time_threshold, ptype, ownership.to_s, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[ownership]*3.3).round, sources_to_ignore, rated_story_thresholds[ownership], num_sources ])
          top_sources[ptype][ownership] = Source.connection.select_all(query)
          puts "Top Sources (#{ptype.upcase}) (#{ownership.to_s})\n\t#{top_sources[ptype][ownership].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t"}"
        }
      }

      puts "------------------------------------------------------"
      puts "Overall Top Sources (by publication type)"
      puts "------------------------------------------------------"
      rated_story_thresholds = Source::RATED_STORY_THRESHOLDS[:publication]
      stmt = "select * from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories,source_media where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.created_at >= ? and source_media.source_id=sources.id and source_media.main=1 and source_media.medium=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
      ["online", "blog", "tv", "radio", "wire"].each { |ptype|
        query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], time_threshold, ptype, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[:all]*3.3).round, sources_to_ignore, rated_story_thresholds[:all], num_sources ])
        top_sources[ptype] = Source.connection.select_all(query)
        puts "Top Sources (#{ptype.upcase})\n\t#{top_sources[ptype].collect { |row| "#{row["name"]} (#{row["id"]}) (#{row["avg_source_rating"]} from #{row["num_stories"]} stories)" } * "\n\t"}"
      }
    end
  end
end
