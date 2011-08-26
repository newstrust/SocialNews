class Admin::BulkEmailsController < Admin::AdminController
  before_filter :find_template, :only => [:show, :edit, :update, :destroy]
  layout 'admin'

  def index
      # rails barfs on the % character!  
      #
      # @templates = BulkEmail.find(:all, :conditions => ["template_name NOT LIKE '%DO NOT EDIT%'"])
      #
      # since we don't expect too many bulk email templates, it is okay to simply fetch all templates
      # into memory and purge unneeded ones.
    @templates = BulkEmail.find(:all).reject { |bm| bm.template_name =~ /DO NOT EDIT/ }
  end

  def new
    @bulk_email = BulkEmail.new
  end

  def create
    @bulk_email = BulkEmail.create(params[:bulk_email])
    if (@bulk_email.valid?)
      flash[:notice] = "Template #{@bulk_email.template_name} successfully created!"
      redirect_to(admin_bulk_email_path(@bulk_email))
    else
      render :template => 'admin/bulk_emails/new'
    end
  end

  def destroy
    @bulk_email.destroy 
    flash[:notice] = "Template #{@bulk_email.template_name} destroyed!"
    redirect_to admin_bulk_emails_path
  rescue Exception => e
    flash[:error] = e
    redirect_to admin_bulk_emails_path
  end

  def update
    @bulk_email.update_attributes(params[:bulk_email])
    if (@bulk_email.valid?)
      redirect_to(admin_bulk_email_path(@bulk_email))
    else
      render :template => 'admin/bulk_emails/edit'
    end
  end

  def setup
    @bulk_email = params[:id] ? BulkEmail.find(params[:id]) : BulkEmail.new
  end

  def send_mail
    max_recipients = SocialNewsConfig["max_recipients_for_synchronous_email_dispatch"]
    params[:bulk_email][:template_name] = (params[:bulk_email][:template_name] || "") + " (DO NOT EDIT! EMAIL QUEUED FOR BACKGROUND DELIVERY)"
    bulk_email = BulkEmail.new(params[:bulk_email])
    bulk_email.local_site = @local_site
    if (bulk_email.to.split("\n").length < max_recipients)
      results = {:notices => ""}
      begin
        errors = bulk_email.dispatch(current_member, results)
        flash[:notice] = errors + results[:notices]
        redirect_to admin_bulk_emails_path
      rescue Exception => e
        flash[:error] = results[:notices] + e.to_s
        flash.discard
        @bulk_email = bulk_email
        render :template => 'admin/bulk_emails/setup'
      end
    else
      bulk_email.save!
      jobs = Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:bulk_email:dispatch id=#{bulk_email.id}", :tag => "bulk_email", :priority => SocialNewsConfig["bj"]["priorities"]["bulk_emails"]
      flash[:notice] = "More than #{max_recipients} recipients.  The email will be sent in the background.  If delivery succeeds, an email notification will be sent to #{bulk_email.from}.  If delivery fails, an alert will be sent out to #{SocialNewsConfig["admin_alert_recipient"]}"
      redirect_to admin_bulk_emails_path
    end
  end
  
  def find_template
    @bulk_email = BulkEmail.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_bulk_emails_path
  end
end
