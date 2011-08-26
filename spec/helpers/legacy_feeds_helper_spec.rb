require File.dirname(__FILE__) + '/../spec_helper'
describe LegacyFeedsHelper do
  include LegacyFeedsHelper
  it "These feed names should parse correctly" do
    @tests = [
      { :t_or_s  => nil,
        :name    => "most_recent",
        :fparams => {:t_slug => nil, :listing_type => "most_recent", :story_type => nil, :source_ownership => nil} },
      { :t_or_s  => nil,
        :name    => "most_trusted",
        :fparams => {:t_slug => nil, :listing_type => "most_trusted", :story_type => nil, :source_ownership => nil} },
      { :t_or_s  => "topics",
        :name    => "for_review",
        :fparams => {:t_slug => nil, :listing_type => "for_review", :story_type => nil, :source_ownership => nil} },
      { :t_or_s  => "topics",
        :name    => "environment_most_trusted_news_ind",
        :fparams => {:t_slug => "environment", :listing_type => "most_trusted", :story_type => "news", :source_ownership => "independent"} },
      { :t_or_s  => "topics",
        :name    => "election_reform_opinion",
        :fparams => {:t_slug => "election_reform", :listing_type => "most_recent", :story_type => "opinion", :source_ownership => nil} },
      { :t_or_s  => "topics",
        :name    => "election_reform_most_trusted_opinion_msm",
        :fparams => {:t_slug => "election_reform", :listing_type => "most_trusted", :story_type => "opinion", :source_ownership => "mainstream"} },
      { :t_or_s  => "topics",
        :name    => "election_reform_for_review_opinion_msm",
        :fparams => {:t_slug => "election_reform", :listing_type => "for_review", :story_type => "opinion", :source_ownership => "mainstream"} },
      { :t_or_s  => "topics",
        :name    => "election_reform_recent_reviews",
        :fparams => {:t_slug => "election_reform", :listing_type => "recent_reviews", :story_type => nil, :source_ownership => nil} },
      { :t_or_s  => "subjects",
        :name    => "health_most_trusted_news_ind",
        :fparams => {:t_slug => "health", :listing_type => "most_trusted", :story_type => "news", :source_ownership => "independent"} },
      { :t_or_s  => "subjects",
        :name    => "politics",
        :fparams => {:t_slug => "politics", :listing_type => "most_recent", :story_type => nil, :source_ownership => nil} },
    ]

    @tests.each { |t|
      get_feed_params(t[:name]).should be == t[:fparams]
    }
  end
end
