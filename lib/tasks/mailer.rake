namespace :socialnews do
  namespace :bulk_email do
    desc "Send out bulk emails!"
    task(:dispatch => :environment) do
      unless ENV.include?("id")
        raise "usage: rake [RAILS_ENV=env_here] socialnews:bulk_email:dispatch id=ID_HERE  # id of the bulk email object"
      end

      results = {:notices => ""}
      begin
        bulk_email = BulkEmail.find(ENV['id'])
        errors = bulk_email.dispatch(Member.nt_bot, results)
        bulk_email.destroy
        email_notice = "#{results[:count]} total emails sent\n\n" + results[:notices] + "\n" + errors
        email_notice.gsub!(/<br>/, "\n")
        Mailer.deliver_generic_email({:recipients => bulk_email.from, :subject => "Bulk Email Sent", :body => email_notice})
      rescue Exception => e
        BulkEmail.logger.error "ERROR sending bulk mail #{ENV['id']}: #{e}\n#{e.backtrace.inspect}"
        email_notice = "Bulk email delivery failed.  Errors have been recorded in the bulk_email log file.\n\nThe list of recipients who received the email (if any were delivered at all) has been recorded in the bulk_email log file and also shown below.\n\n #{results[:notices].gsub(/<br>/, "\n")}"
        Mailer.deliver_admin_alert(email_notice)
      end
    end
  end

  namespace :emails do
    desc "Send out summary email with site activity"
    task(:send_site_activity_log => :environment) do
      # Send out an email with:
      #    1. new members
      #    2. a list of posted stories
      #    3. reviewed but still in pending/queued status
      #    4. story reviews
      #    5. posted comments
      # since last email was sent out
      row = PersistentKeyValuePair.find_by_key("post_summary.last_sent_at")
      last_sent_time = Time.parse(row.value)
      new_sent_time  = Time.now
      new_members        = Member.find(:all, :conditions => ["created_at > ?", last_sent_time]) 
      posted_stories     = Story.find(:all, :conditions => ["status in (?) AND created_at > ?", [Story::LIST, Story::FEATURE], last_sent_time])
      incomplete_stories = Story.find(:all, :select => "distinct stories.*", 
                                            :joins => "JOIN reviews on reviews.story_id=stories.id", 
                                            :conditions => ["reviews.created_at > ?", last_sent_time]).reject { |s| s.can_be_listed? && s.is_public? }
      new_reviews        = Review.find(:all, :conditions => ["status in (?) AND created_at > ?", [Review::LIST, Review::FEATURE], last_sent_time])
      new_comments       = Comment.find(:all, :conditions => ["hidden=false AND created_at > ?", last_sent_time])

      # Send it off!
      Mailer.deliver_site_activity_log(last_sent_time, :new_members        => new_members,
                                                       :posted_stories     => posted_stories, 
                                                       :incomplete_stories => incomplete_stories,
                                                       :new_reviews        => new_reviews,
                                                       :new_comments       => new_comments)

      # Update last sent time
      row.update_attribute(:value, new_sent_time.to_s)
    end
  end

  namespace :notifications do
    desc "Send out pending email notifications"
    task(:process_pending => :environment) do
      unless ENV.include?("type")
        raise "usage: rake [RAILS_ENV=env_here] socialnews:notifications:process_pending type=...  # type of the notifications (quote:link, story:edit, etc.)"
      end

      notification_type = ENV["type"]
      
      # Accumulate all notifications on a per-member basis
      h = {}
      PendingNotification.find_all_by_notification_type(notification_type).each { |pn|
        ls_id = pn.local_site_id || 0  # Local site id
        h[ls_id] ||= {}
        h[ls_id][pn.member_id] ||= []
        h[ls_id][pn.member_id] <<= pn
      }

      # Tell the responsible class to handle the notifications
      class_name, action = notification_type.split(":")
      h.keys.each { |ls_id|
        ls = (ls_id == 0) ? nil : LocalSite.find(ls_id)
        NotificationMailer.setup_local_site(ls)
        class_name.capitalize.constantize.process_pending_notifications(h[ls_id], action)
      }
    end
  end
end
