require File.dirname(__FILE__) + '/../spec_helper'

describe Tag do
  fixtures :all
  describe 'being created' do
    it "should create a tag" do
      lambda do
        Tag.create(:name => "name")
      end.should change(Tag, :count).by(1)
    end
  end
  
  describe "being accessed" do
    it "should find tags by popularity" do
      @whales = tags(:whales)
      @car = tags(:car)
      5.times do
        @car.taggings.create(:taggable_id => 1, :taggable_type => 'Story')
      end
      Tag.find_popular(:limit => 1).first.should == @car
      
      10.times do
        @whales.taggings.create(:taggable_id => 1, :taggable_type => 'Story')
      end
      
      Tag.find_popular(:limit => 1).first.should == @whales
    end
  end

  describe "tagger" do
    it 'should quote multi-word tags correctly' do
      tag = "two words"
      q_tag = Tag.quote(tag)
      q_tag.should_not == tag
      (q_tag =~ /".*"/).should_not be_nil
    end

    it 'should not quote single-word tags' do
      tag = "tag"
      q_tag = Tag.quote(tag)
      q_tag.should == tag
    end

    it 'should remove commas from tags where possible' do
      tag = "Obama, Barack"
      q_tag = Tag.curate(tag)
      q_tag.should == "Barack Obama"
    end
  end
end
