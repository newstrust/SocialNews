require File.dirname(__FILE__) + '/../spec_helper'

describe WidgetsController do
  fixtures :all

  before(:each) do
    @only_host = members(:legacy_member)
    @environment = topics(:environment)
    @election_reform = topics(:election_reform)

      ## Make sure the fixtures are loaded correctly!
    assert_not_nil @only_host
    assert_not_nil @environment
    assert_not_nil @election_reform

      ## Set up various widget tests to run through!
    @tests = [
      { :t_or_s => nil,        :name => "most_recent", :wparams => ["", "most_recent", "", ""] },
      { :t_or_s => nil,        :name => "most_trusted", :wparams => ["", "most_trusted", "", ""] },
      { :t_or_s => "topics",   :name => "for_review", :wparams => ["", "for_review", "", ""] },
      { :t_or_s => "topics",   :name => "environment_most_trusted_news_ind", :wparams => ["environment", "most_trusted", "news", "ind"] },
      { :t_or_s => "topics",   :name => "election_reform_opinion", :wparams => ["election_reform", "most_recent", "opinion", ""] },
      { :t_or_s => "topics",   :name => "election_reform_most_trusted_opinion_msm", :wparams => ["election_reform", "most_trusted", "opinion", "msm"] },
      { :t_or_s => "topics",   :name => "election_reform_for_review_opinion_msm", :wparams => ["election_reform", "for_review", "opinion", "msm"] },
      { :t_or_s => "topics",   :name => "election_reform_recent_reviews", :wparams => ["election_reform", "recent_reviews", "", ""] },
      { :t_or_s => "subjects", :name => "health_most_trusted_news_ind", :wparams => ["health", "most_trusted", "news", "ind"] },
      { :t_or_s => "subjects", :name => "politics", :wparams => ["politics", "most_recent", "", ""] },
    ]

    @fail_tests = [
      { :t_or_s => nil,      :name => "most_trusted_" },
      { :t_or_s => nil,      :name => "environment" },
      { :t_or_s => "topics", :name => "environment_most_trusted_ind_news" },
      { :t_or_s => "topics", :name => "environment_most_recent_ind_news" },
      { :t_or_s => "nil",    :name => "most_trusted_for_review" }
    ]
  end

  describe ": Test widgets" do
    it ": These widgets should be fetched and rendered correctly" do
      @tests.each { |t| 
        #puts "S-Test #{t[:name]}"
        get :get_legacy_widget_data, :t_or_s => t[:t_or_s], :widget_name => t[:name]
        response.should be_success
        response.should render_template('get_legacy_widget_data')
        response.template.assigns["metadata"]["listing_topic"].length.should > 0 if (t[:wparams][0] != "") 
      }
    end

    it ": These widgets should fail" do
      @fail_tests.each { |t| 
        #puts "F-Test #{t[:name]}"
        get :get_legacy_widget_data, :t_or_s => t[:t_or_s], :widget_name => t[:name]
        response.response_code.should == 404
      }
    end
  end
end
