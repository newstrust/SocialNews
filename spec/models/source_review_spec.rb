require File.dirname(__FILE__) + '/../spec_helper'

describe SourceReview do
  fixtures :all

  it "should lookup topics from topic ids" do
	 ts = Topic.find(:all, :limit => 3)
	 s = Source.find(:first)
	 m = Member.find(:first)
	 s = SourceReview.new(:expertise_topic_ids => ts.map(&:id) * ",", :source_id => s.id, :member_id => m.id)
	 s.expertise_topics.map(&:id).sort.should == ts.map(&:id).sort
  end

  it "should be incomplete if missing rating" do
	 s = Source.find(:first)
	 m = Member.find(:first)
	 SourceReview.new(:source_id => s.id, :member_id => m.id, :expertise_topic_ids => "1", :note => "abcd").incomplete?.should be_true
  end

  it "should be incomplete if missing notes and expertise" do
	 s = Source.find(:first)
	 m = Member.find(:first)
	 SourceReview.new(:source_id => s.id, :member_id => m.id, :rating => 1).incomplete?.should be_true
  end

  it "should not be incomplete if it has a rating and missing only one of notes and expertise" do
	 s = Source.find(:first)
	 m = Member.find(:first)
	 SourceReview.new(:source_id => s.id, :member_id => m.id, :rating => 1, :note => "abcd").incomplete?.should be_false
	 SourceReview.new(:source_id => s.id, :member_id => m.id, :rating => 1, :expertise_topic_ids => "1,2").incomplete?.should be_false
  end
end
