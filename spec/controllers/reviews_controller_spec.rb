require File.dirname(__FILE__) + '/../spec_helper'

module ReviewSpecHelper
  def valid_story_rating_attributes
    {"facts"=>{"criterion"=>"facts", "value"=>"3"}, "originality"=>{"criterion"=>"originality", "value"=>""}, "knowledge"=>{"criterion"=>"knowledge", "value"=>""}, "insight"=>{"criterion"=>"insight", "value"=>""}, "depth"=>{"criterion"=>"depth", "value"=>""}, "accuracy"=>{"criterion"=>"accuracy", "value"=>""}, "information"=>{"criterion"=>"information", "value"=>""}, "enterprise"=>{"criterion"=>"enterprise", "value"=>""}, "verification"=>{"criterion"=>"verification", "value"=>""}, "sourcing"=>{"criterion"=>"sourcing", "value"=>""}, "transparency"=>{"criterion"=>"transparency", "value"=>""}, "relevance"=>{"criterion"=>"relevance", "value"=>""}, "recommendation"=>{"criterion"=>"recommendation", "value"=>"1"}, "context"=>{"criterion"=>"context", "value"=>""}, "fairness"=>{"criterion"=>"fairness", "value"=>""}, "style"=>{"criterion"=>"style", "value"=>""}, "balance"=>{"criterion"=>"balance", "value"=>""}, "expertise"=>{"criterion"=>"expertise", "value"=>""}}
  end

  def valid_review_params
    {"review"=>{
      "story_id"=>1,
      "rating_attributes"=>valid_story_rating_attributes},
      "source_ratings"=>{"trust"=>{"criterion"=>"trust", "value"=>"4"}}}
  end

  def new_review_params
    { "review"=> {
        "story_id"=>1,
        "rating_attributes"=>valid_story_rating_attributes,
        "excerpts_attributes"=>[{"body"=>"hurray! quote!", "should_destroy"=>"false", "comment"=>""}], 
        "comment" => "note test",
        "personal_comment" => "personal comment test"
      },
      "source_ratings"=>{"trust"=>{"criterion"=>"trust", "value"=>"4"}}
    }
  end
end

describe ReviewsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  include ReviewSpecHelper

  fixtures :all
  
  it "should process overall_rating" do
    spec_login_as(members(:legacy_member))
    get :overall_rating, valid_review_params
    response.should be_success
  end

  describe "creating new review" do
    before(:each) do
      ProcessJob.delete_all
      spec_login_as(members(:heavysixer))
      lambda do
        post :create, new_review_params
        response.should be_success
      end.should change(Review, :count).by(1)
    end

    it "should add a new review to the db with the right values" do
      r = Review.find(:last)
      r.should_not be_nil
      r.comment.should == "note test"
      r.personal_comment.should == "personal comment test"
      r.excerpts.length.should == 1
      r.excerpts[0].body.should =~ /hurray! quote!/
    end

    it "should queue a ProcessJob for propagating review ratings" do
      r = Review.find(:last)
      r.should_not be_nil

      pj = ProcessJob.find(:first, :conditions => {:processable_type => "Review"})
      pj.should_not be_nil
      pj.processable.should == r
    end
  end

  describe "posting a story review without a source review" do
    before(:each) do
      @m = members(:heavysixer)
      spec_login_as(@m)
      @params = new_review_params
      @params["source_ratings"]["trust"]["value"] = "0"
    end

    it "should not create a source review" do
      lambda do
        post :create, @params
        response.should be_success
      end.should_not change(SourceReview, :count)
    end

    it "should not queue a ProcessJob for a source review" do
      ProcessJob.delete_all
      post :create, @params
      response.should be_success

      pj = ProcessJob.find(:first, :conditions => {:processable_type => "SourceReview"})
      pj.should be_nil
    end
  end

  describe "posting a review with fresh source rating attributes" do
    it "should create a source review" do
      m = members(:heavysixer)
      lambda do
        spec_login_as(m)
        post :create, new_review_params
        response.should be_success
      end.should change(SourceReview, :count).by(1)

      r = Review.find(:last)
      sr = SourceReview.find(:last)
      sr.member_id.should == m.id
      sr.source_id.should == r.story.primary_source_id
      sr.rating.should == new_review_params["source_ratings"]["trust"]["value"].to_i
    end

    it "should queue a ProcessJob for propagating source review ratings" do
      m = members(:heavysixer)
      spec_login_as(m)
      post :create, new_review_params
      response.should be_success

      pj = ProcessJob.find(:first, :conditions => {:processable_type => "SourceReview"})
      pj.should_not be_nil
      pj.processable.should == SourceReview.find(:last)
    end
  end

  describe "posting a review with fresh source rating attributes for an existing source review" do
    before(:each) do
      @m = members(:heavysixer)
      spec_login_as(@m)
      @params = new_review_params
      s = Story.find(@params["review"]["story_id"])
      @sr = SourceReview.find_or_create_by_source_id_and_member_id(s.primary_source.id, @m.id)
      @sr.update_attribute(:rating, 4)
    end

    it "should update the existing source review" do
      lambda do
        @params["source_ratings"]["trust"]["value"] = "3"
        post :create, @params
        response.should be_success
      end.should_not change(SourceReview, :count)

      @sr.reload
      @sr.rating.should == 3
    end

    it "should queue a ProcessJob for the source review if the rating is different" do
      ProcessJob.delete_all
      @params["source_ratings"]["trust"]["value"] = "5"
      post :create, @params
      response.should be_success

      pj = ProcessJob.find(:first, :conditions => {:processable_type => "SourceReview"})
      pj.should_not be_nil
      pj.processable.should == SourceReview.find(:last)
    end

    it "should not queue a ProcessJob for the source review if the rating is identical" do
      ProcessJob.delete_all
      @params["source_ratings"]["trust"]["value"] = "4"
      post :create, new_review_params
      response.should be_success

      pj = ProcessJob.find(:first, :conditions => {:processable_type => "SourceReview"})
      pj.should be_nil
    end
  end

  #---- testing story rating propagation integration ----
  describe "posting a review" do
    it "should initialize story rating to that review's rating if it is the first review" do
      m = members(:legacy_member)
      s = Story.create(:title => "Test", :url => "http://dummydomain.com/1", :excerpt => "dummy", :stype_code => 1, :rating => 0, :story_date => Time.now.to_date, :status => "list", :editorial_priority => 4, :primary_source_id => 1, :submitted_by_id => m.id)
      spec_login_as(m)
      opts = new_review_params
      opts["review"]["story_id"] = s.id
      post :create, opts
      response.should be_success

      r = Review.find(:last)
      r.story.should == s
      s.reload
      s.reviews_count.should == 1
      s.rating.should == r.rating
    end

    # 2nd review by a different member should not update story rating right away
    it "should not change story rating if it is not the story's first review" do
      m2 = members(:heavysixer)
      spec_login_as(m2)

      s = Story.find(:last, :joins => [:reviews], :conditions => "reviews.member_id != #{m2.id} and reviews_count > 0")
      old_rating = s.rating
      old_count = s.reviews_count

      opts = new_review_params
      opts["review"]["story_id"] = s.id
      post :create, opts
      response.should be_success

      r = Review.find(:last)
      r.story.should == s
      r.member.should == m2
      s.reload
      s.reviews_count.should == old_count +1
      s.rating.should == old_rating
    end
  end
  
end
