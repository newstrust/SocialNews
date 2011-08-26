require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../../lib/mail_blocker'

describe ActionMailer::Base do
  app_domain = SocialNewsConfig["app"]["domain"]
  @@test_recipients = [ "sastry@cs.wisc.edu", "david@#{app_domain}", "fabrice@#{app_domain}", "sss.lists@gmail.com", "georgebush@outofthere.now", "god@nowhere.net", "god@everywhere.in" ]
  @@approved_list   = [ "sastry@cs.wisc.edu", "david@electriceggplant.com", "adamflorin@gmail.com" ]

  tests = [
    { :flag => false, :result => ["sastry@cs.wisc.edu"] },
    { :flag => true,  :result => ["sastry@cs.wisc.edu", "david@#{app_domain}", "fabrice@#{app_domain}"] }
  ]

  def init_mailer(nt_domain_flag)
    ActionMailer::Base.send_to_nt_domain = nt_domain_flag
    ActionMailer::Base.nt_approved_recipients = @@approved_list
  end

  it 'should block mails to non-approved recipients' do
    tests.each { |t|
      init_mailer(t[:flag])
      ActionMailer::Base.nt_devmode_filter_recipients(@@test_recipients).should == t[:result]
    }
  end
end
