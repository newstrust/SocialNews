class Admin::NewsletterController < Admin::AdminController
  layout 'admin'

  include MembersHelper
  include MailerHelper

  def index
    @newsletter_freqs = LocalSite.newsletter_frequencies(@local_site)
  end

  def setup
    freq = params[:freq]
    @newsletter = Newsletter.fetch_latest_newsletter(freq, current_member)
    if (@newsletter.state == Newsletter::IN_TRANSIT)
      flash[:error] = "Sorry! You cannot edit the #{@newsletter.freq} newsletter any more -- it is being mailed out to subscribers already!"
      redirect_to admin_newsletter_url, :status => :found
    end
  end

  def preview
    freq = params[:freq]
    @newsletter = Newsletter.fetch_latest_newsletter(freq, current_member)
    @tmail = Mailer.create_html_newsletter(@newsletter, current_member)
    render :layout => "minimal"
  end

  def update
    newsletter = Newsletter.find(params[:newsletter][:id])  ## fetch by id, not by latest
    params[:newsletter].delete(:id) ## get rid of the :id param

      ## Change from auto --> ready .. the newsletter is now controlled by editors
    params[:newsletter][:state] = Newsletter::READY if (newsletter.state == Newsletter::AUTO)

    if newsletter.update_attributes(params[:newsletter])
      flash[:notice] = "The newsletter was successfully updated.  Please preview the newsletter below"
      newsletter.log_action "Updated by #{current_member.id}:#{current_member.name}"
      redirect_to nl_preview_url(:freq => newsletter.freq)
    else
      redirect_to nl_setup_url(:freq => newsletter.freq)
    end
  end

  def refresh_stories
    freq = params[:freq]
    newsletter = Newsletter.fetch_latest_newsletter(freq, current_member)

      # If the newsletter is being sent out, no refresh!
    if newsletter.state == Newsletter::IN_TRANSIT
      flash[:error] = "Sorry!  The newsletter is being dispatched.  It cannot be refreshed now!"
    else
        ## If in auto, the stories will get refreshed automatically -- so, don't do it once more!
      newsletter.refresh_stories if (newsletter.state != Newsletter::AUTO)
      newsletter.log_action "Stories refreshed by #{current_member.id}:#{current_member.name}"
    end

    redirect_to nl_preview_url(:freq => newsletter.freq)
  end

  def reset_template
    freq = params[:freq]
    @newsletter = Newsletter.fetch_latest_newsletter(freq, current_member)
        # If the newsletter is being sent out, no reset!
    if @newsletter.state == Newsletter::IN_TRANSIT
      flash[:error] = "Sorry!  The newsletter is being dispatched.  The templates cannot be reset now!"
    else
      @topic = Topic.featured_topic(@local_site) || Topic.find(:first)
      @link_params = newsletter_link_params(freq)
      if freq == Newsletter::MYNEWS
        @newsletter.subject     = render_to_string :template =>  "newsletter/mynews/subject", :layout => false
        @newsletter.text_header = render_to_string :template =>  "newsletter/mynews/text/header", :layout => false
        @newsletter.text_footer = render_to_string :template =>  "newsletter/mynews/text/footer", :layout => false
        @newsletter.html_header = render_to_string :template =>  "newsletter/mynews/html/header", :layout => false
        @newsletter.html_footer = render_to_string :template =>  "newsletter/mynews/html/footer", :layout => false
      else
        @newsletter.subject     = render_to_string :template => "newsletter/subject", :layout => false
        @newsletter.text_header = render_to_string :template => "newsletter/text/header", :layout => false
        @newsletter.text_footer = render_to_string :template => "newsletter/text/footer", :layout => false
        @newsletter.html_header = render_to_string :template => "newsletter/html/header", :layout => false
        @newsletter.html_footer = render_to_string :template => "newsletter/html/footer", :layout => false
      end
      @newsletter.save!
      @newsletter.log_action "Headers & footers reset by #{current_member.id}:#{current_member.name}"
    end

    redirect_to nl_setup_url(:freq => @newsletter.freq)
  end

  def send_test_mail
    freq        = params[:freq]
    newsletter  = Newsletter.fetch_latest_newsletter(freq, current_member)
    member_refs = params[:member_refs]
    if params[:to_myself]
      member_refs = (member_refs.nil?) ? "#{current_member.name}" : "#{current_member.name}\n#{member_refs}"
    end

    begin 
      notices = ""
      errors = process_member_refs(member_refs) { |m, mref|
        wants_newsletter = m.has_newsletter_subscription?(freq)
        if !wants_newsletter
          notices += "Not sent to #{mref} because the member has disabled newsletter delivery<br>"
        elsif (m.newsletter_format == 'html')
          Mailer.deliver_html_newsletter(newsletter, m)
          notices += "Sent HTML newsletter to #{mref}<br>"
        else
          Mailer.deliver_text_newsletter(newsletter, m)
          notices += "Sent TEXT newsletter to #{mref}<br>"
        end
      }
      flash[:notice] = notices + errors
    rescue Exception => e
      flash[:error] = e.to_s
    end
    redirect_to nl_preview_url(:freq => freq)
  end

  def send_now
    freq = params[:freq]
    newsletter = Newsletter.fetch_latest_newsletter(freq, current_member)

      # Update dispatch time and BJ job id
    newsletter.dispatch_time = Time.now
    newsletter.save!

      # Submit to bj!
    newsletter.submit_to_bj

    flash[:notice] = "The newsletter will be sent out now ..."
    redirect_to admin_newsletter_url, :status => :found
  end
end
