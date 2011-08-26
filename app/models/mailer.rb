class Mailer < ActionMailer::Base
  helper ActionView::Helpers::UrlHelper
  helper :application
  ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS

  SUBJECT_PREFIX = ""
  APP_NAME = SocialNewsConfig["app"]["name"]

  @@recipient_limit = 25
  cattr_reader :recipient_limit
  
  helper ActionView::Helpers::UrlHelper
  helper :mailer, :application, :reviews, :stories, :members, :sources
  include MailerHelper # NO idea why it's not getting included by the 'helper' call above

  def self.setup_local_site(local_site)
    if local_site
      ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS.merge(:host => local_site.subdomain_path)
    else
      ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS
    end
  end
  
  def reset_password(options)
    setup_email(options)
  end
  
  def signup_notification(member)
    setup_email(:recipients => member.email,
                :subject    => "Welcome to #{APP_NAME} - Activate Your Account",
                :from       =>  SocialNewsConfig["email_addrs"]["signup"],
                :body       => { :member => member, :url => "#{activate_members_url}/#{member.activation_code}" })
  end
  
  def partner_signup_notification(member)
    invite_link = "#{activate_members_url}/#{member.activation_code}"
    setup_email(:recipients => member.email,
                :cc         => SocialNewsConfig["email_addrs"]["registrations"],
                :subject    => member.invitation.email_subject,
                :from       => member.invitation.email_from,
                :body       => Invitation.format_invitation_email(member, member.invitation, invite_link))
  end

  def signup_invitation_notification(member)
    
    # For some reason when inside the association this belong_to assocation returns nil so 
    # we need to explicitly find it.
    @referring_member = Member.find(member.referred_by)
    
    setup_email(:recipients => member.email,
                :subject => "#{@referring_member.name} invited you to join #{APP_NAME}",
                :from    =>  SocialNewsConfig["email_addrs"]["signup"],
                :body    => { :member => member,
                              :referring_member => @referring_member,
                              :url => "#{accept_invitation_members_url}/#{member.activation_code}" })
  end

  def fb_activation(member)
    setup_email(:recipients => member.email,
                :subject    => "Welcome to #{APP_NAME} - Your Account Has Been Created",
                :from       =>  SocialNewsConfig["email_addrs"]["signup"],
                :body       => { :member => member })
  end

  def activation(member)
    setup_email(:recipients => member.email,
                :subject    => "Welcome to #{APP_NAME} - Your Account Has Been Activated",
                :from       =>  SocialNewsConfig["email_addrs"]["signup"],
                :body       => { :member => member })
  end

  def text_newsletter(newsletter, recipient)
    Mailer.setup_local_site(newsletter.associated_local_site)
    setup_newsletter_body(newsletter) if newsletter.text_body.nil?
    setup_email(:recipients => "\"#{recipient.name}\"<#{recipient.email}>",
                :from       => SocialNewsConfig["email_addrs"]["news"],
                :body       => render_message("newsletter/text/mail", :recipient => recipient, :newsletter => newsletter, :story_body => newsletter.text_body))
    @subject = newsletter.subject_line  ## Setting it here to avoid the subject prefix from setup_email
  end

  def html_newsletter(newsletter, recipient)
    Mailer.setup_local_site(newsletter.associated_local_site)
    setup_newsletter_body(newsletter) if newsletter.html_body.nil?
    setup_email(:recipients => "\"#{recipient.name}\"<#{recipient.email}>",
                :from       => SocialNewsConfig["email_addrs"]["news"])
    @subject = newsletter.subject_line
    @content_type = "multipart/alternative"
    part :content_type => "text/plain",
         :body         => render_message("newsletter/text/mail", :recipient => recipient, :newsletter => newsletter, :story_body => newsletter.text_body)
    part :content_type => "text/html",
         :body         => render_message("newsletter/html/mail", :recipient => recipient, :newsletter => newsletter, :story_body => newsletter.html_body)
  end

  def mynews_text_newsletter(newsletter, listing, recipient)
    body = render_message "newsletter/mynews/text/body", :newsletter => newsletter, :listing => listing, :member => recipient
    setup_email(:recipients => "\"#{recipient.name}\"<#{recipient.email}>",
                :from       => SocialNewsConfig["email_addrs"]["news"],
                :body       => render_message("newsletter/mynews/text/mail", :recipient => recipient, :newsletter => newsletter, :story_body => body))
    @subject = newsletter.subject  ## Setting it after setup_email to override the subject prefix from setup_email
  end

  def mynews_html_newsletter(newsletter, listing, recipient)
    setup_email(:recipients => "\"#{recipient.name}\"<#{recipient.email}>",
                :from       => SocialNewsConfig["email_addrs"]["news"])

    link_params = newsletter_link_params(newsletter.freq)
    @content_type = "multipart/alternative"
    t_body = render_message "newsletter/mynews/text/body", :newsletter => newsletter, :listing => listing, :member => recipient, :link_params => link_params
    h_body = render_message "newsletter/mynews/html/body", :newsletter => newsletter, :listing => listing, :member => recipient, :link_params => link_params
    part :content_type => "text/plain",
         :body         => render_message("newsletter/mynews/text/mail", :recipient => recipient, :newsletter => newsletter, :story_body => t_body, :link_params => link_params)
    part :content_type => "text/html",
         :body         => render_message("newsletter/mynews/html/mail", :recipient => recipient, :newsletter => newsletter, :story_body => h_body, :link_params => link_params)
    @subject = newsletter.subject  ## Setting it after setup_email to override the subject prefix from setup_email
  end

  def admin_alert(msg)
    setup_email(:recipients => SocialNewsConfig["admin_alert_recipient"], :subject => 'RAILS ALERT!', :body => msg)
  end

  def feed_fetch_log(fetch_log)
    setup_email(:recipients => SocialNewsConfig["fflog_recipient"],
                :from => SocialNewsConfig["email_addrs"]["bot"],
                :subject => "Feed Fetch Log",
                :body => render_message("mailer/feed_fetch_log", fetch_log))
  end

  def site_activity_log(last_sent_time, activities)
    setup_email(:recipients => SocialNewsConfig["activity_log_recipient"],
                :from => SocialNewsConfig["email_addrs"]["bot"],
                :subject => "Site Activity Log",
                :body => render_message("mailer/site_activity_log", activities.merge(:last_sent_time => last_sent_time)))
  end

  def feed_fetch_success_email(feed_id, bj_job, recipient)
    setup_email(:recipients => recipient,
                :subject => "Feed #{feed_id} has been fetched", 
                :body => render_message("mailer/feed_fetched", :feed => Feed.find(feed_id), :bj_job => bj_job))
  end

  def fb_newsfeed_fetch_success_email(feed_id, member)
    setup_email(:recipients => member.email,
                :subject => "Check your Facebook Feed on #{APP_NAME}", 
                :body => render_message("mailer/fb_newsfeed_fetched", :member => member, :feed => Feed.find(feed_id)))
  end

  def twitter_newsfeed_fetch_success_email(feed_id, member)
    setup_email(:recipients => member.email,
                :subject => "Check your Twitter Feed on #{APP_NAME}", 
                :body => render_message("mailer/twitter_newsfeed_fetched", :member => member, :feed => Feed.find(feed_id)))
  end

  # Don't confuse this method with the class method of the same name. This is the one called
  # when you use Mailer.deliver_send_to_friend()
  def send_to_friend(params, template, record = nil)
    ActivityScore.boost_score(record, :email) if (record.class == Story)
    setup_email(:recipients => params[:to],
                :from       => "\"#{params[:from_name]}\"<#{params[:from]}>",
                :from_name  => params[:from_name],
                :body       => render_message("mailer/send_to_friend/#{template}", :record => record, :recipient => params[:to], :page =>params[:page], :body => params[:body]))
    @subject = "#{params[:from_name]} sent you a link to #{APP_NAME}"
  end

  def bulk_email(bm, recipient)
    options = {
      :subject => bm.subject,
      :from => bm.from,
      :recipients => recipient.email,
    }
    if bm.html_mail
      options[:text_body] = render_message("bulk_email_template", :body => bm.body, :recipient => recipient)
      options[:html_body] = render_message("bulk_email_template", :body => bm.html_body, :recipient => recipient)
      multipart_email(options)
    else
      options[:body] = render_message("bulk_email_template", :body => bm.body, :recipient => recipient)
      generic_email(options)
    end
  end

  private

    def setup_newsletter_body(newsletter)
      tsnm = newsletter.most_recent_news_msm
      newsletter.subject_line = (newsletter.add_top_story_title_to_subject && !tsnm.empty?) ? newsletter.subject + h(tsnm.first.title) : newsletter.subject
      view_params = {:newsletter => newsletter, :link_params => newsletter_link_params(newsletter.freq)}
      newsletter.text_body = render_message("newsletter/text/body", view_params)
      newsletter.html_body = render_message("newsletter/html/body", view_params)
    end

    # Create placeholders for whichever e-mails you need to deal with.
    # Override mail elements where necessary
    def setup_email(options)
      @recipients = options[:recipients]
      @from = options[:from] || SocialNewsConfig["email_addrs"]["support"] 
      @cc = options[:cc] || ''
      @bcc = options[:bcc] || ''
      @subject = SUBJECT_PREFIX + (options[:subject] || 'No Subject')
      @body = options[:body] || {}
      @headers = options[:headers] || {}
      @charset = options[:charset] || 'utf-8'
    end

    def generic_email(options)
      setup_email(options)
    end

    def multipart_email(options)
      setup_email(options)
      @content_type = "multipart/alternative"
      part :content_type => "text/plain", :body => options[:text_body]
      part :content_type => "text/html", :body => options[:html_body]
    end
    
    def comment_posted(options)
      setup_email(options)
    end
  
  class << self
    def send_to_friend(params = {})
      raise(ArgumentError, "Your email address is required.") unless params && params[:from] && !params[:from].empty?
      raise(ArgumentError, "Your email address is not valid.") unless valid_email_address?(params[:from])
      raise(ArgumentError, "Please specify at least one recipient.") unless params[:to]  && !params[:to].empty?
      record, template = find_template(params)
      good, undeliverable = extract_emails_from_string(params[:to], ',')
      
      raise(ArgumentError, "The recipient address is malformed.") if good.empty?
      
      # Only send messages to the first 25 recipients
      good[0..@@recipient_limit-1].each do |recipient|
        params[:to] = recipient ## Update params[:to] to send to only this recipient .. if not, everyone gets N copies each
        deliver_send_to_friend(params, template, record)
      end
      sent = good[0..@@recipient_limit-1]
      unsent = good[@@recipient_limit..-1] || []
      
      [sent, unsent, undeliverable]
    end
    
    def find_template(params)
      raise(ArgumentError, "Email could not be sent because no valid page was found to send.") unless params[:template] && params[:record_id]
      template = "#{params[:template]}.erb"
      file_name = File.join( RAILS_ROOT, 'app/views/mailer/send_to_friend/', template)
      file_name = File.exist?(file_name) ? template : "generic.erb"
      
      case file_name
        when "member_profile.erb"
          record = Member.find(params[:record_id])
        when "member_review.erb"
          record = Review.find(params[:record_id])
        when "home.erb"
        when  "source.erb"
          record = Source.find(params[:record_id])
        when "story.erb"
          record = Story.find(params[:record_id])
          record.increment(:emails_count).save
          record.process_in_background
        when "subject.erb"
          record = Subject.find(params[:record_id])
        when "topic.erb"
          record = Topic.find(params[:record_id])
      end
      
      [record, file_name]
    end
    
    def extract_emails_from_string(emails_str, seperator)
       good = []
       bad = []
       
       # Remove duplicates and white spaces between words
       arr = emails_str.split(",").each { |x| x.strip! }.uniq
       
       arr.each do |address|
         valid_email_address?(address) ? good << address : bad << address
       end
       
       [good,bad]
    end
    
    def valid_email_address?(address = '')
      (address =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i) != nil && !address.nil?
    end
  end
end
