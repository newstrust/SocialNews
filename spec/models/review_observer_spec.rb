require File.dirname(__FILE__) + '/../spec_helper'

describe ReviewObserver do
  fixtures :all
  
  before(:each) do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
  end
  
  it "should queue pending notifications to submitter on new review" do
    lambda do
      lambda do
        review = Review.new({:story => stories(:unreviewed_story), :rating => 5, :member => members(:trusted_member)})
        review.save_and_process_with_propagation
        ProcessJob.find(:all).map(&:process)
      end.should_not change(ActionMailer::Base.deliveries, :size)
    end.should change(PendingNotification, :count).by(1)
  end

  it "should not queue pending notifications to submitter on updated review" do
    lambda do
      lambda do
        reviews(:thoughtful_review).save_and_process_with_propagation
      end.should_not change(ActionMailer::Base.deliveries, :size)
    end.should_not change(PendingNotification, :count)
  end
  
end
