require File.dirname(__FILE__) + '/../spec_helper'

describe RssFeedsController do
  def get_feed(feed_name, feed_cat = nil)
    get :get_legacy_rss_feed, :feed_cat => feed_cat, :feed_name => feed_name
  end

  describe "redirect old feeds to new ones" do
    it "should handle index.xml" do
     get_feed("index")
     response.status.should =~ /301/
     response.should redirect_to("/stories/most_recent.xml")
    end
   
    it "should handle most_trusted_ind.xml" do
      get_feed("most_trusted_ind")
      response.status.should =~ /301/
      response.should redirect_to("/stories/most_trusted/independent.xml")
    end
   
    it "should handle subjects/us.xml" do
      get_feed("us", "subjects")
      response.status.should =~ /301/
      response.should redirect_to("/subjects/us/most_recent.xml")
    end
  end
end
