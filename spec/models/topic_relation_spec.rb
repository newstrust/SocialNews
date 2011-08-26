require File.dirname(__FILE__) + '/../spec_helper'

describe TopicRelation do
  fixtures :all
  describe 'being accessed' do
    it "should return a list of available topic subjects" do
      ["world", "us"].each do |topic|
        TopicRelation.topic_subjects.include?(topic)
      end
    end
    
    it "should return a hash of groupings for a topic subject" do
      lambda do
        @grouping = TopicRelation.topic_subject_groupings('foo')
      end.should raise_error(RuntimeError)
      
      @grouping = TopicRelation.topic_subject_groupings('us')
      # @grouping["us"]["name"].should == "U.S." # let's not test config data!
    end
  end
end
