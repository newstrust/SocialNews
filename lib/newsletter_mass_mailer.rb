# This code has been copied and heavily adapted from the version available at: http://www.myowndb.com/blog/?p=20

require 'net/smtp'
require 'enumerator'

module NewsletterMassMailer
  def self.dispatch(freq)
    #names = ['Subramanya Sastry'] # ['Subramanya Sastry', 'David Fox', 'David Fox2', 'Adam Florin']
    #recipient_ids = Member.find(:all, :conditions => { :name => names, "#{freq}_newsletter" => true }, :select => "id")
    #dispatch_to(freq, recipient_ids)

    # don't slurp all member objects into memory and waste it!  just fetch the ids and fetch the member object, on demand, one at a time!
    # skip nt_bot, we'll add it to the end of the queue
    dispatch_to(freq, Newsletter.subscriber_ids(freq).map(&:id))
  end

  module Debug
    def self.dump_mynews_html_newsletter(m_id, filename = "/tmp/mynews.html")
      File.open(filename, "w") { |f|
        nl   = Newsletter.fetch_latest_newsletter(Newsletter::MYNEWS, Member.nt_bot)
        mail = MynewsHelper.new.html_newsletter(nl, Member.find(m_id))
        f.write(mail.body) 
      }
    end

    def self.dump_mynews_text_newsletter(m_id, filename = "/tmp/mynews.txt")
      File.open(filename, "w") { |f|
        nl   = Newsletter.fetch_latest_newsletter(Newsletter::MYNEWS, Member.nt_bot)
        mail = MynewsHelper.new.text_newsletter(nl, Member.find(m_id))
        f.write(mail.body) 
      }
    end

    def self.send_mynews_html_newsletter(m_id)
      nl = Newsletter.fetch_latest_newsletter(Newsletter::MYNEWS, Member.nt_bot)
      m = Member.find(m_id)
      listing = MynewsHelper.new.listing(m)
      Mailer.deliver_mynews_html_newsletter(nl, listing, m)
    end
  end

  class MynewsHelper
    include MynewsListing

    def listing(m)
      mynews_listing(m, :stories_per_page => 20)
    end

    def text_newsletter(newsletter, recipient)
       listing = mynews_listing(recipient, :stories_per_page => 20)
       # Dont send MyNews email for members where the story list is empty!
       Mailer.create_mynews_text_newsletter(newsletter, listing, recipient) if !listing[:stories].blank?
    end

    def html_newsletter(newsletter, recipient)
       listing = mynews_listing(recipient, :stories_per_page => 20)
       # Dont send MyNews email for members where the story list is empty!
       Mailer.create_mynews_html_newsletter(newsletter, listing, recipient) if !listing[:stories].blank?
    end
  end

  private

  # number of mails sent in one connection to the smtp server
  SENDING_BATCH_SIZE=SocialNewsConfig["newsletter"]["sending_batch_size"]

  def self.go_for_it(newsletter, recipient_ids)
    if newsletter.disabled?
      puts "Newsletter cannot be dispatched -- its has been disabled!  Aborting!"
      newsletter.log_error "Newsletter cannot be dispatched -- its has been disabled!  Aborting!"
      return
    end

    if !newsletter.can_dispatch?
      puts "Newsletter cannot be dispatched -- its state is #{newsletter.state}!  Aborting!"
      newsletter.log_error "Newsletter cannot be dispatched -- its state is #{newsletter.state}!  Aborting!"
      return
    end

      ## Update the dispatch time to now!
    newsletter.dispatch_time = Time.now
    newsletter.save!

    newsletter.log_action "----- Beginning mass delivery at #{Time.now} -----"

      ## FIXME: This is not a sure-shot way of detecting interrupts ...
      ## This could also happen if someone submits the mass mailing job multiple times ..
      ## If coming through Bj, each newsletter is dispatched only once  ... but, this 
      ## can happen when done manually (via the rake task, runner, console, etc.)
    if (newsletter.state == Newsletter::IN_TRANSIT)
      newsletter.log_action "Was this newsletter interrupted while in transit?  It has an 'in_transit' state.  Resuming dispatch anyway!"
    else
      newsletter.mark_in_transit
    end

    mynews_helper = MynewsHelper.new if newsletter.freq == Newsletter::MYNEWS

    exceptions = []
    smtp_settings = ActionMailer::Base.smtp_settings
    recipient_ids.each_slice(SENDING_BATCH_SIZE) do |recipients_slice|
      retry_count = 0
      begin
        Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain], 
                        smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |sender|
          recipients_slice.each do |recipient_id|
            recipient = Member.find(recipient_id)
              ## Looks like we have some empty email ids!
            next if recipient.email.blank?

              ## Ignore non-member accounts (suspended, deleted, guest, etc.)
            next if ((recipient.status != 'member') && (recipient.status != 'duplicate'))

              ## Check if the user wants this kind of newsletter!
            next if !recipient.has_newsletter_subscription?(newsletter.freq)

              ## Check if this newsletter has been delivered previously!
            delivery_notice = newsletter.get_delivery_notice(recipient)
            if delivery_notice.nil?
                # This newsletter has not yet been delivered!  Send it out!
              if recipient.newsletter_format == 'text'
                tmail = (newsletter.freq == Newsletter::MYNEWS) ? mynews_helper.text_newsletter(newsletter, recipient) \
                                                                : Mailer.create_text_newsletter(newsletter, recipient)
              else
                tmail = (newsletter.freq == Newsletter::MYNEWS) ? mynews_helper.html_newsletter(newsletter, recipient) \
                                                                : Mailer.create_html_newsletter(newsletter, recipient)
              end

              if tmail.nil?
                ## Dont send MyNews email for members where the story list is empty!
                newsletter.log_action "NOT sending mynews mail to #{recipient.name} @ '#{recipient.email}' because story list is empty"
                next 
              else
                newsletter.log_action "Sending #{recipient.newsletter_format.upcase} mail to #{recipient.name} @ '#{recipient.email}'"
              end

              tmail.to = ["#{recipient.email}"]

                ## Protection from sending unwanted emails when in development/staging mode!!
              if (ActionMailer::Base.respond_to?("nt_devmode_filter_recipients"))
                tmail.to = ActionMailer::Base.nt_devmode_filter_recipients(tmail.destinations)
              end

                ## Now, send it out!
              if (ActionMailer::Base.perform_deliveries == false)
                newsletter.log_action "ActionMailer::Base.perform_deliveries flag is set to false.  Not sending email but, recording in the DB that email was delivered."
                newsletter.record_delivery_notice(recipient)
              elsif (!tmail.to.nil? && (tmail.to.size > 0))  ## Looks like ActionMailer::Base nils the 'to' field if it is empty!
                begin
                  sender.sendmail tmail.encoded, tmail.from, tmail.to
                  newsletter.record_delivery_notice(recipient)
                rescue Exception => e
                  exceptions << [recipient.email, e] 
                    # needed as the next mail will send command MAIL FROM, which would 
                    # raise a 503 error: "Sender already given"
                  sender.finish
                  sender.start
                end
              else
                newsletter.record_delivery_notice(recipient)
                newsletter.log_action "SMTP mail to #{recipient.email} blocked in development environment!  Recording in the DB that email was delivered."
              end
            else
              newsletter.log_action "IGNORING: Newsletter was previously delivered to #{recipient.name} @ #{recipient.email} @ #{delivery_notice.created_at}"
            end
          end
        end
      rescue Exception => e
        puts "-----------------"
        puts e.backtrace.inspect 
        puts "-----------------"
        retry_count += 1
        if retry_count > 5
          puts "Giving up! 5 failed attempts to connect with the smtp server"
          newsletter.log_error "Giving up! 5 failed attempts to connect with the smtp server"
          raise e
        else
          puts "Failed to connect with SMTP server.  Retrying .. attempt #{retry_count}"
          newsletter.log_error "Failed to connect with SMTP server.  Retrying .. attempt #{retry_count}"
          retry
        end
      end
    end

    if exceptions.length > 0
      newsletter.log_error "---- Exceptions recorded while sending newsletter ----"
      newsletter.log_error "#{YAML.dump(exceptions)}"
      puts "#{YAML.dump(exceptions)}"
    end

    newsletter.mark_sent
  end

  # NOTE: recipient_ids MUST be an array of Member ids, not of Member objects!
  def self.dispatch_to(freq, recipient_ids)
#    unless [Newsletter::MYNEWS, Newsletter::DAILY, Newsletter::WEEKLY].include?(freq)
#      Newsletter.logger.error "--- NOT dispatching #{freq} newsletter at this time.  Ignoring the dispatch request.  Current time: #{Time.now} ---"
#      return
#    end

      ## IMPORTANT: Use 'fetch_prepared_newsletter', not 'fetch_latest_newsletter'
      ## This keeps concerns separate.  The mass mailer is only concerned with mailing out a prepared newsletter.
      ## How it is prepared is the main application's concern.  fetch_latest_newsletter, at this time, creates
      ## a newsletter, if one doesn't exist.  But, this should have happened during the course of normal application
      ## execution.  If one doesn't exist, it is a bug.
		n = Newsletter.fetch_prepared_newsletter(freq)
		if n.nil?
      Mailer.deliver_admin_alert("Newsletter Mass Mailer: There is no #{freq.humanize} newsletter ready for dispatch.  Throwing up my hands!")
		  Newsletter.logger.error "There is no #{freq.humanize} newsletter ready for dispatch.  Throwing up my hands!"
		else
        # Refresh stories if the stories are too stale!
      n.refresh_stories if ((n.dispatch_time - (n.refreshed_at || n.updated_at)) > SocialNewsConfig["newsletter"]["max_stale_stories_age_in_mins"].minutes)

		  go_for_it(n, recipient_ids)

        # Send a last one to nt_bot so that we know how long it took for all the newsletters to get delivered
      Mailer.deliver_text_newsletter(n, Member.nt_bot)
      n.log_action "Sending LAST text mail to the #{SocialNewsConfig["app"]["name"]} bot!"
		end
  end
end
