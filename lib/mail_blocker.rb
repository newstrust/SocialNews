## The following code is a much-modified version of that found @ http://manuals.rubyonrails.com/read/chapter/64
## This ensures that emails sent out through ActionMailer in the development environment are only dispatched 
## to recipients in an approved list.

class ActionMailer::Base
  @@nt_approved_recipients = []
  @@send_to_nt_domain = false

  def self.nt_approved_recipients=(r)
    @@nt_approved_recipients = r
  end

  def self.send_to_nt_domain=(flag)
    @@send_to_nt_domain = flag
  end

  def self.nt_devmode_filter_recipients(destinations)
    return if destinations.nil?

      ## Filter the list of email recipients
    destinations = destinations.collect{|x|
       (@@send_to_nt_domain && (x =~ /@#{SocialNewsConfig["app"]["domain"]}/)) ? x : @@nt_approved_recipients.collect{ |y| (x==y) ? x : nil }
    }.flatten.compact
  end

  def perform_delivery_smtp(mail)
    destinations = ActionMailer::Base.nt_devmode_filter_recipients(mail.destinations)
    if destinations.size > 0
      mail.ready_to_send
      sender = (mail['return-path'] && mail['return-path'].spec) || Array(mail.from).first
      smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
      smtp.enable_starttls_auto if smtp_settings[:enable_starttls_auto] && smtp.respond_to?(:enable_starttls_auto)
      smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
        smtp.sendmail(mail.encoded, sender, destinations)
      end
    else
      puts "SMTP mail to #{mail.to} blocked in your development environment!"
      RAILS_DEFAULT_LOGGER.info("SMTP mail to #{mail.to} blocked in development environment!")
    end
  end

  def perform_delivery_sendmail(mail)
    destinations = ActionMailer::Base.nt_devmode_filter_recipients(mail.destinations)
    if destinations.size > 0
      mail.to = destinations
      sendmail_args = sendmail_settings[:arguments]
      sendmail_args += " -f \"#{mail['return-path']}\"" if mail['return-path']
      IO.popen("#{sendmail_settings[:location]} #{sendmail_args}","w+") do |sm|
        sm.print(mail.encoded.gsub(/\r/, ''))
        sm.flush
      end
    else
      puts "Sendmail mail to #{mail.to} blocked in your development environment!"
      RAILS_DEFAULT_LOGGER.info("Sendmail mail to #{mail.to} blocked in development environment!")
    end
  end
end
