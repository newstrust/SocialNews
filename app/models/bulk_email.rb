class BulkEmail < ActiveRecord::Base
  belongs_to :local_site

    # :to, :is_reinvite, :invitation_code can be empty -- they can be filled out just before emailing!
  validates_presence_of :template_name, :from, :subject, :body

  include ActionController::UrlWriter  
  include MembersHelper

  # Set up a logger to log information about bulk emails that went out
  @logger = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}_bulk_mails.log")
  @logger.formatter = RailsFormatter.new

  def self.logger; @logger; end

  def dispatch(sender, results)
    results[:notices] = ""
    results[:count]   = 0
    Mailer.setup_local_site(self.local_site)
    errors = process_member_refs(to) { |m, mref|
      if (!is_reinvite || (m.status == 'guest'))
        if (!invitation_code.blank?)
          x = m.invitation_code
            # BUG in the flex_attributes plugin? update_attribute (singular) does not work for flex_attributes
          m.update_attributes({:invitation_code => x.blank? ? invitation_code : "#{x},#{invitation_code}"})
        end
          # Generate activation code if it is nil -- for example this happens for members who signed up before October 2008.
        m.make_activation_code if (m.activation_code.nil?)
          # Don't send email if member opted out of "Special Notices", unless email form says to ignore this
        if (m.bulk_email || self.ignore_no_bulk_email || is_reinvite)
          Mailer.deliver_bulk_email(self, m)
          BulkEmail.logger.info "#{sender.name} sent bulk mail to #{m.email}"
          results[:notices] += "Sent mail to #{mref}<br>"
          results[:count] += 1
        else
         results[:notices] += "Not sending email to #{mref} because the member has set Special Notices to #{m.bulk_email}<br>"
        end
      elsif (is_reinvite && m.status != 'guest')
        results[:notices] += "Not sending the reinvitation mail to #{mref} because the member has #{m.status} status <br>"
      end
    }

    return errors
  end
end
