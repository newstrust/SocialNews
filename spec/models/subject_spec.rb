require File.dirname(__FILE__) + '/../spec_helper'

describe Subject do
  fixtures :all

  it 'should identify high-volume subjects' do
    politics = Subject.find_by_slug("politics")
    politics.topic_volume = SocialNewsConfig["high_volume_subject_days"]
    politics.save!
    politics.is_high_volume?.should be_true
    politics.topic_volume = SocialNewsConfig["high_volume_subject_days"] + 1
    politics.save!
    politics.is_high_volume?.should be_false
  end

  describe 'being searched' do
    it "should return only subjects" do
      s = Subject.find(:first)
      ThinkingSphinx.stub!(:search).and_return(s)
      @results = Subject.search(s.name)
      @results[0].class.should == s.class
    end
  end
  
  describe 'being edited' do
    it "should return a list of groupings and group values" do
      @politics = topics(:politics)

      ["us_elections", "us_government", "political_issues"].each do |group|
        @politics.groupings.include?(group).should be_true
      end
      
      @politics.grouping("us_elections").should == "U.S. Elections"
      @politics.grouping("some_invalid_group").should == nil
    end
  end
end
