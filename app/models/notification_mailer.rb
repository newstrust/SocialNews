class NotificationMailer < ActionMailer::Base
  helper ActionView::Helpers::UrlHelper
  helper :mailer, :application, :reviews, :stories, :members, :sources
  ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS

  SUBJECT_PREFIX = ""
  APP_NAME = SocialNewsConfig["app"]["name"]

  def self.setup_local_site(local_site)
    if local_site
      ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS.merge({:host => local_site.subdomain_path})
    else
      ActionMailer::Base.default_url_options = APP_DEFAULT_URL_OPTIONS
    end
  end

  def edit_alert(options)
    setup_email(:recipients => SocialNewsConfig["email_addrs"]["edits"], :subject => options[:subject], :body => options[:body])
  end

  def story_edited(options)
  	subj = ""
  	if options[:body][:recipient]
  		if options[:body][:recipient] == options[:body][:submitter]
  			subj = "you posted "
  		else
  			subj = "you edited "
  		end
  	end
    setup_email(options.merge({ :subject =>  "#{options[:body][:editor].display_name} edited a story " + subj + "on #{APP_NAME}" }))
  end

  def submitted_story_reviewed(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:reviewer].display_name} reviewed a story you posted on #{APP_NAME}" }))
  end
  def reviewed_story_reviewed(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:reviewer].display_name} reviewed a story you rated on #{APP_NAME}" }))
  end
  def liked_story_reviewed(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:reviewer].display_name} reviewed a story you starred on #{APP_NAME}" }))
  end

  def review_notifications_digest(options)
    setup_email(options.merge({:subject => "New #{options[:body][:num_reviews] == 1 ? "review" : "reviews"} on #{APP_NAME}"}))
    @body = render_message("notification_mailer/reviews/notification_digest", options[:body])
  end

  def submitted_story_liked(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:liker].display_name} starred a story you posted on #{APP_NAME}" }))
  end
  def review_meta_reviewed(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:rater].display_name} rated your review on #{APP_NAME}" }))
  end
  def followed_member(options = {})
    setup_email(options.merge({ :subject => "#{options[:body][:follower].display_name} is now following you on #{APP_NAME}" }))
  end

  def review_comment(options={})
    setup_email(options)
    @body = render_message("notification_mailer/comments/review/new", options[:body])
  end

  # Delivered to the comment parent and siblings of the new comment
  def comment_replied_to(options = {})
    send_comment_notification(options, "reply_notice")
  end

  def liked_comment_replied_to(options = {})
    send_comment_notification(options, "liked_comment_reply_notice")
  end

  def like_content_notice(options = {})
    send_comment_notification(options, "liked_comment_notice")
  end

  def flag_content_notice(options = {})
    send_comment_notification(options, "flagged_notice")
  end

  private

  def setup_email(options = {})
		if options[:to_member_id]
			@recipients = "#{options[:to_member_id]}"
    elsif options[:to_member]
      @recipients = "#{options[:to_member].display_name} <#{options[:to_member].email}>"
    else
      @recipients = options[:recipients]
    end
    @from = options[:from] || SocialNewsConfig["email_addrs"]["support"] 
    @cc = options[:cc] || ''
    @bcc = options[:bcc] || ''
    @subject = SUBJECT_PREFIX + (options[:subject] || 'No Subject')
    @body = options[:body] || {}
    @headers = options[:headers] || {}
    @charset = options[:charset] || 'utf-8'
  end

  def send_comment_notification(options, notice_type)
    setup_email(options)

    # Identify the template to use
    comment = options[:body][:record]
    notice_template = "notification_mailer/comments/#{comment.commentable.class.to_s.downcase}/#{notice_type}" if comment.commentable

    # If the notice template is empty of it doesn't exist, use the default!
    if notice_template.nil? || !File.exists?("#{RAILS_ROOT}/app/views/#{notice_template}.erb")
      notice_template = "notification_mailer/comments/default/#{notice_type}" 
    end

    # SSS: options[:body][:to] can be nil because the notifier code (in models or observers) might not have set it up if the template doesn't need it
    @body = render_message(notice_template, options[:body])
  end
end
