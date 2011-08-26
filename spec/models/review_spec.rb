require File.dirname(__FILE__) + '/../spec_helper'

module ReviewSpecHelper
  def valid_rating_params
    { "sourcing"=>{"criterion"=>"sourcing", "value"=>"1"},
      "information"=>{"criterion"=>"information", "value"=>""},
      "style"=>{"criterion"=>"style", "value"=>"3"} }
  end
end

describe Review do
  include ReviewSpecHelper
  fixtures :all
  
  it "should save correctly" do
    @review = Review.new({
      :story => stories(:legacy_story),
      :member => members(:heavysixer)})
    @review.rating_attributes = valid_rating_params
    
    lambda do
      @review.save
    end.should change(Review, :count)
  end
  
  it "should update child ratings correctly, creating/deleting by criterion" do
    extant_review = reviews(:one_review)
    
    lambda do
      extant_review.ratings.length.should be(3)
      extant_review.rating_attributes = valid_rating_params
      extant_review.save.should be_true
      extant_review.ratings.length.should be(2)
    end.should change(Rating, :count)
    
    # make sure trust rating was wiped out
    Rating.find(:first, :conditions => {
      :ratable_id => extant_review.id,
      :ratable_type => "Review",
      :criterion => "information"}).should be_nil
  end

  it "should, when hidden/listed, update reviews_count of reviewed story" do
    r = reviews(:one_review)
    s = Story.find(r.story_id)
    orig_count = s.reviews_count

    r.status = "hide"
    r.save!
    s.reload.reviews_count.should == orig_count - 1

    r.status = "list"
    r.save!
    s.reload.reviews_count.should == orig_count
  end

  it "should discount non-ratable reviews (those with pre-specified disclosure values) from reviews_count of reviewed story" do
    r = reviews(:one_review)
    s = Story.find(r.story_id)
    orig_count = s.reviews_count

    r.disclosure = "author"
    r.save!
    s.reload.reviews_count.should == orig_count - 1
  end

  it "should find group-specific metareviews" do
    r = reviews(:one_review)
    mrs       = r.meta_reviews
    mr_groups = mrs[0].member.groups
    rest      = Group.find(:all) - mr_groups

    mrs.length.should > 0                                 # Fixture validation
    mr_groups.length.should > 0                           # Fixture validation
    rest.length.should > 0                                # Fixture validation

    r.meta_reviews_from_group(nil).should == mrs          # sitewide

    gmr = r.meta_reviews_from_group(mr_groups[0])
    gmr.length.should > 0
    gmr.should_not == mrs
  end

  describe "finding featured review" do
    before(:each) do
      @m = members(:heavysixer)
      @m.update_attributes(:status => Member::MEMBER, :rating => 3.5, :validation_level => 3)
      @s = Story.find(:last, :conditions => {:status => [Story::LIST, Story::FEATURE]})
      @r = Review.create(:member_id => @m.id, :story_id => @s.id, :comment => "This is a long enough comment -- the quick brown fox jumps over the lazy dog -- but not yet long enough, so I have to type more nonsensical words!", :rating => 3.5)
    end

    describe "should always" do
      it "find the most recent review" do
        Review.featured_review.should == @r
      end

      it "find the review with note at least 10 characters long" do
        Review.featured_review.should == @r
        @r.update_attribute(:comment, "short")
        Review.featured_review.should_not == @r
      end

# No longer relevant since we turned off no-staff-reviews constraint
#
#      it "ignore reviews from staff when it is time to ignore" do
#        Review.stub!("show_staff_reviews?").and_return(false)
#        Review.featured_review.should == @r
#        @r.update_attribute(:member_id, Member::ACTIVE_STAFF_IDS.first)
#        Review.featured_review.should_not == @r
#      end
#
#      it "not ignore reviews from staff when it is time not to ignore" do
#        Review.stub!("show_staff_reviews?").and_return(true)
#        Review.featured_review.should == @r
#        @r.update_attribute(:member_id, Member::ACTIVE_STAFF_IDS.first)
#        Review.featured_review.should == @r
#      end

      it "ignore reviews from terminated members" do
        Review.featured_review.should == @r
        @m.update_attribute(:status, Member::TERMINATED)
        Review.featured_review.should_not == @r
      end

      it "ignore reviews from stories that are not in list/feature status" do
        Review.featured_review.should == @r
        (Story::ALL_STATUS_VALUES - [Story::LIST, Story::FEATURE]).each { |s|
          @s.update_attribute(:status, s)
          Review.featured_review.should_not == @r
        }
      end

      it "ignore reviews from untrusted members" do
        Review.featured_review.should == @r
        @m.update_attribute(:rating, 2.5)
        Review.featured_review.should_not == @r
      end

      it "ignore reviews from members with validation level less than 3" do
        Review.featured_review.should == @r
        @m.update_attribute(:validation_level, 2)
        Review.featured_review.should_not == @r
      end
    end

    describe "on a subject page" do
      it "should find a review pertaining to the subject" do
        subj = Subject.find(:last)
        @r.story.taggings = []
        Review.featured_review(nil, subj).should_not == @r
        @r.story.taggings << Tagging.new(:tag_id => subj.tag_id)
        Review.featured_review(nil, subj).should == @r
      end
    end

    describe "on a topic page" do
      it "should find a review pertaining to the topic" do
        topic = Topic.topics_only.find(:last)
        @r.story.taggings = []
        Review.featured_review(nil, topic).should_not == @r
        @r.story.taggings << Tagging.new(:tag_id => topic.tag_id)
        Review.featured_review(nil, topic).should == @r
      end
    end

    describe "on the national site" do
      it "should not find reviews on a local-scope story" do
        Review.featured_review.should == @r
        @r.story.update_attribute(:is_local, true)
        Review.featured_review.should_not == @r
      end
    end

    describe "on a local site" do
      before(:each) do
        @ls = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
      end

      it "should find a review for a story on that site" do
        @r.story.taggings = []
        Review.featured_review(@ls).should_not == @r
        @r.story.taggings << Tagging.new(:tag_id => @ls.constraint_id)
        Review.featured_review(@ls).should == @r
      end

      it "on a subject page should find a review for a story on that site that belongs to the subject" do
        @r.story.taggings = [Tagging.new(:tag_id => @ls.constraint_id)]
        subj = Subject.find(:last, :conditions => "tag_id != #{@ls.constraint_id}")
        Review.featured_review(@ls, subj).should_not == @r
        @r.story.taggings << Tagging.new(:tag_id => subj.tag_id)
        Review.featured_review(@ls, subj).should == @r
      end
    end
  end
end
