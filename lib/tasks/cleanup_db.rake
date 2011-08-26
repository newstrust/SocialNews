namespace :socialnews do
  def time_it
    t1 = Time.now
    out = yield
    t2 = Time.now
    puts "#{out} in #{t2-t1} seconds"
  end

  desc "Delete stale sessions and other stale data from the db"
  task(:cleanup_db => :environment) do
    time_it {
      month_ago = Time.now - 30.days
      time_it {
        nsd = CGI::Session::ActiveRecordStore::Session.delete_all(["updated_at < ?", month_ago])
        "Deleted #{nsd} sessions"
      }

      time_it {
        nbd = Bj.table.job_archive.delete_all(["archived_at < ?", month_ago])
        "Deleted #{nbd} archived bj jobs"
      }

        # Delete pending stories from the db that have:
        # (a) not been linked as a related story to anything
        # (b) not been viewed by any member (guest views dont count)
        # (c) no public reviews
        # (d) not been saved by anyone
        # (e) not been linked to a quote
        # Process 1000 at a time
      num_iter = 0
      while (true) do
        t1 = Time.now
        stories_to_delete = Story.find(:all,
          :joins => " left join story_clicks on story_clicks.story_id=stories.id and length(data) < 10" +
                    " left join story_relations sr1 ON sr1.story_id=stories.id" +
                    " left join story_relations sr2 ON sr2.related_story_id=stories.id" +
                    " left join saves ON saves.story_id=stories.id" +
                    " left join quote_links ON quote_links.story_id=stories.id" +
                    " left join reviews ON reviews.story_id=stories.id AND reviews.status in ('list','feature')",
          :conditions => ["stories.status = ? AND saves.id IS NULL AND reviews.id IS NULL AND sr1.id IS NULL AND sr2.id IS NULL AND story_clicks.id IS NULL AND quote_links.id IS NULL AND sort_date < ?", Story::PENDING, Time.now - 7.days],
          :select => "stories.id",
          :limit => 1000)
        t2 = Time.now
        n = 0
        stories_to_delete.each { |s| 
          begin
            Story.find(s.id).destroy 
            n += 1
          rescue Exception => e
            puts "Exception #{e} trying to delete story #{s.id}.  Leaving it alone!"
          end
        }
        t3 = Time.now
        puts "Deleted #{n} pending stories; Query time: #{t2-t1} seconds; Delete time: #{t3-t2} seconds"

        # If we got less than 1000 stories, this is probably the last iteration
        break if stories_to_delete.length < 1000

        # Catch the rare case where we are in danger of getting stuck in an infinite loop
        num_iter += 1
        break if num_iter > 100
      end

      # Delete pending sources from the db without any associated stories
      # Delete sources after stories in case additional sources are deletable
      t1 = Time.now
      srcs_to_delete = Source.find(:all, 
        :conditions => ["status = 'pending' AND NOT EXISTS (SELECT * FROM authorships WHERE source_id = sources.id) AND NOT EXISTS (SELECT * FROM feeds WHERE source_profile_id = sources.id)"], 
        :select => "id")
      t2 = Time.now
      n = 0
      srcs_to_delete.each { |s|
        begin
          Source.find(s.id).destroy 
          n += 1
        rescue Exception => e
          puts "Exception #{e} trying to delete source #{s.id}.  Leaving it alone!"
        end
      }
      t3 = Time.now
      puts "Deleted #{n} pending sources without any stories; Query time: #{t2-t1} seconds; Delete time: #{t3-t2} seconds"

        # Delete unclaimed guest reviews that are over a week old
      time_it {
        guest_reviews = Review.find(:all, :conditions => ["member_id IS NULL AND created_at < ?", Time.now - 7.days], :select => "id")
        n = 0
        guest_reviews.each { |r|
          begin
            Review.find(r.id).destroy
            n += 1
          rescue Exception => e
            puts "Exception #{e} trying to delete guest review #{r.id}.  Leaving it alone!"
          end
        }
        "Deleted #{n} unclaimed guest reviews!"
      }

#    # Purge api info from the story_attributes table for stories that are over 1 week old
#    StoryAttribute.delete_all(["name in (?) AND created_at < ?", MetadataFetch:APIS.keys.collect { |api| api.to_s + "_info"} * ',', Time.now - 7.days])

#    # Purge story bodies from the story attributes table for stories that are over 1 week old
      time_it {
        StoryAttribute.delete_all(["name='body' AND created_at < ?", Time.now - 7.days])
        "Deleted stale story body attributes!"
      }

        # Optimize the processed ratings table -- this table sees a good deal of delete activity
        # -- Also optimize the other tables which see deletions
      time_it {
        ProcessedRating.connection.execute('optimize table processed_ratings')
        "optimized processed_ratings"
      }
      time_it {
        Rating.connection.execute('optimize table ratings')
        "optimized ratings"
      }
      time_it {
        Review.connection.execute('optimize table reviews')
        "optimized reviews"
      }
      time_it {
        Source.connection.execute('optimize table sources')
        "optimized sources"
      }
      time_it {
        Source.connection.execute('optimize table source_attributes')
        "optimized source_attributes"
      }
      time_it {
        Story.connection.execute('optimize table stories')
        "optimized stories"
      }
      time_it {
        StoryAttribute.connection.execute('optimize table story_attributes')
        "optimized story_attributes"
      }
      time_it {
        Authorship.connection.execute('optimize table authorships')
        "optimized authorships"
      }
      time_it {
        Tagging.connection.execute('optimize table taggings')
        "optimized taggings"
      }
      "Completed entire db cleanup task"
    }
  end
end
