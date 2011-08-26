require File.dirname(__FILE__) + '/../spec_helper'

describe CommentObserver do
  fixtures :all
  
  before(:each) do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  # See the CommentControllerSpec for notification tests.  

  it "should send a notification to the host of a topic" do
  end
end
