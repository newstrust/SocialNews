require File.dirname(__FILE__) + '/../spec_helper'

class MynewsTester
  include MynewsListing

  def test_settings(m, f=true)
    mynews_settings(m, f)
  end
end

describe MynewsListing do
  fixtures :all

  describe "computing settings hash" do
    before(:each) do
      @m = members(:heavysixer)
      @tester = ::MynewsTester.new
    end

    it "should use default value when a member hasn't picked a value for a setting" do
      h = @tester.test_settings(@m)
      MynewsListing::MYNEWS_DEFAULT_SETTINGS.each { |k,v| h[k].should != v[1] }
    end

    it "should use override default value when a member has picked a value" do
      @m.stories_per_page = 2
      @m.min_matching_criteria = 3
      h = @tester.test_settings(@m)
      h[:stories_per_page].should == 2
      h[:min_matching_criteria].should == 3
    end

    it "should pick default settings for stories_per_page if it is not my mynews page" do
      @m.min_matching_criteria = 3
      @m.stories_per_page = 2
      h = @tester.test_settings(@m, false)
      h[:min_matching_criteria].should == 3
      h[:stories_per_page].should == MynewsListing::MYNEWS_DEFAULT_SETTINGS[:stories_per_page][1]
    end
  end
end
