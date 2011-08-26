require File.dirname(__FILE__) + '/../spec_helper'

module ProcessableSpecHelper
  def valid_story_attributes
    { :title => "Breaking Story",
      :url => "http://news-provider.com/breaking-story.htm",
      :story_type => "news_report",
      :story_date => Time.now,
      :submitted_by_id => 1 }
  end
  
  def valid_rating_attributes
    { :criterion => "context",
      :value => 3 }
  end
end

describe "acts_as_processable" do
  include ProcessableSpecHelper
  fixtures :all

  describe "processing and propagating ratings" do
    before(:each) do
      @legacy_member = members(:legacy_member)
      @legacy_story = stories(:legacy_story)
      @legacy_source = sources(:legacy_source)
      @one_review = reviews(:one_review)
      @new_story = Story.new(valid_story_attributes)
#      @social_group = groups(:social_group)
      @social_group = Group.new(:name => "admins", :description => "nothing", :context => "social", :is_protected => true, :slug => "admins")
      @social_group.sg_attrs = SocialGroupAttributes.new(:visibility => "private", :activated => false, :num_init_story_days => 7, :membership_mode => "open", :listings => "activity most_recent starred", :status => "list", :tag_id_list => "")
      @social_group.save!
      @social_group.deactivate!
    end

    describe "should process all dependents in the background for" do
      describe "non-group" do
        before(:each) do
          ProcessJob.destroy_all
          ProcessJob.find(:all).length.should == 0
        end

        it "reviews" do
          review = Review.find(:first)
          review.save_and_process_with_propagation.should be_true
          ProcessJob.find(:all, :conditions => {:group_id => nil}).length.should > 0
          ProcessJob.find(:all, :conditions => {:group_id => @social_group.id}).length.should == 0
        end

        it "meta-reviews" do
          mr = MetaReview.find(:first)
          mr.save_and_process_with_propagation.should be_true
          ProcessJob.find(:all, :conditions => {:group_id => nil}).length.should > 0
          ProcessJob.find(:all, :conditions => {:group_id => @social_group.id}).length.should == 0
        end

        it "stories" do
          s = Story.find(:first)
          s.save_and_process_with_propagation.should be_true
          ProcessJob.find(:all, :conditions => {:group_id => nil}).length.should > 0
          ProcessJob.find(:all, :conditions => {:group_id => @social_group.id}).length.should == 0
        end
      end

      describe "group" do
        before(:each) do
          Story.update_all(:story_date => Time.now) # make sure there will be stories upon activation!
          @social_group.activate!
          @social_group.add_member(@legacy_member)
          ProcessJob.destroy_all
          ProcessJob.find(:all).length.should == 0
        end

        it "story saves should add process_jobs for recomputing group ratings, but nothing for non-group rating" do
          s = GroupStory.find(:first).story
          s.save_and_process_with_propagation(true, @social_group).should be_true
          ProcessJob.find(:all, :conditions => {:group_id => nil}).length.should == 0
          ProcessJob.find(:all, :conditions => {:group_id => @social_group.id}).length.should > 0
        end

        it "review saves should add process_jobs for recomputing group ratings, but nothing for non-group rating" do
          s = GroupStory.find(:first).story
          review = s.reviews.first || Review.new(:story_id => s, :member_id => @legacy_member.id, :rating => 4)
          review.save_and_process_with_propagation(true, @social_group).should be_true
          ProcessJob.find(:all, :conditions => {:group_id => nil}).length.should == 0
          ProcessJob.find(:all, :conditions => {:group_id => @social_group.id}).length.should > 0
        end
      end
    end

    describe "ratings for non-group stories" do
      it "should propagate ratings calculation from reviews through members, stories, and sources" do
        ProcessedRating.delete_all  # SSS: Why do we need this?
        ProcessedRating.count.should be_zero
        @new_story.rating.should_not be

        # assign source to story
        @new_story.authorships << Authorship.new(:source => @legacy_source)

        # review our new story
        review = Review.new({ :member => @legacy_member, :story => @new_story, :ratings => [Rating.new(valid_rating_attributes)]})

        # trigger save w/ propagate: causes everything to get one or more processed_ratings
        ProcessedRating.count.should be_zero
        review.save_and_process_with_propagation.should be_true
        ProcessedRating.count.should_not be_zero

        # specific rating of 3 should have propagated to review, story & source
        review.reload.rating.should eql(3.0)
        @new_story.reload.rating.should > 0.0

        old_rating = @legacy_member.reload.rating

        # do background processing
        ProcessJob.find(:all).map(&:process)
        ProcessJob.find(:all).map(&:process)

        # member should have processed_ratings, although not 100% sure what they'd be
        @legacy_member.reload.rating.should_not == old_rating
      end
      
      it "should make sure new stories have a rating" do
        #stories(:unreviewed_story).rating.should be_nil
        stories(:unreviewed_story).save_and_process_with_propagation
        stories(:unreviewed_story).rating.should_not be_nil
      end
      
      it "should save historic ratings" do
        lambda do
          @one_review.ratings = [Rating.new(:criterion=>"context", :value=>1)]
          @one_review.save_and_process_with_propagation
        end.should change(ProcessedRatingVersion, :count)
      end
    end
  end
  
  describe "weighted averages" do
    
    it "should favor the opinion of a trusted member" do
      stories(:unreviewed_story).processed_rating("style").should be_nil
      
      # trusted member says the style sux
      trusted_review = Review.new({
        :member => members(:trusted_member),
        :story => stories(:unreviewed_story),
        :ratings => [Rating.new({:criterion => "style", :value => 1})]})
      trusted_review.save_and_process_with_propagation.should be(true)
      trusted_review.processed_rating("quality").should == 1.0
      
      # but tweedle-dee here thinks it was downright spiffy
      untrusted_review = Review.new({
        :member => members(:untrustworthy_member),
        :story => stories(:unreviewed_story),
        :ratings => [Rating.new({:criterion => "style", :value => 5})]})
      untrusted_review.save_and_process_with_propagation.should be(true)
      untrusted_review.processed_rating("quality").should == 5.0

      ProcessJob.find(:all).map(&:process)
      ProcessJob.find(:all).map(&:process)

      # so the story quality is low.
      stories(:unreviewed_story).reload.processed_rating("quality").should eql(1.2)
      
      # final review should be weighted closer to trusted member's rating
      trusted_delta = (stories(:unreviewed_story).processed_rating("quality") - trusted_review.processed_rating("quality")).abs
      untrusted_delta = (stories(:unreviewed_story).processed_rating("quality") - untrusted_review.processed_rating("quality")).abs
      trusted_delta.should < untrusted_delta
      
      # now that we have confidence, we can check this the easier way, too.
      untrusted_review.processed_rating("confidence").should < trusted_review.processed_rating("confidence")
    end
    
    it "should temper story rating confidence based on number of reviews" do
      reviews(:one_review).save_and_process_with_propagation
      ProcessJob.find(:all).map(&:process)
      ProcessJob.find(:all).map(&:process)
      reviews(:one_review).story.processed_rating("confidence").should < reviews(:one_review).processed_rating("confidence")
    end
    
    it "should favor quality above popularity" do
      #stories(:unreviewed_story).rating.should be_nil
      
      uneven_review = Review.new({
        :member => members(:trusted_member),
        :story => stories(:unreviewed_story),
        :ratings => [
          Rating.new(:criterion => "style", :value => 1), # quality criterion
          Rating.new(:criterion => "recommendation", :value => 5)]}) # popularity criterion
      uneven_review.save_and_process_with_propagation.should be(true)
      
      delta_to_quality = (stories(:unreviewed_story).reload.rating - uneven_review.processed_rating("quality")).abs
      delta_to_popularity = (stories(:unreviewed_story).reload.rating - uneven_review.processed_rating("popularity")).abs
      delta_to_quality.should < delta_to_popularity
    end
    
    it "should factor in source trust rating even if reviewer filled in no other ratings" do
      stories(:unreviewed_story).save_and_process_with_propagation.should be(true)
      old_rating = stories(:unreviewed_story).rating
      old_rating.should_not be_nil
      
      lambda do
        sr = SourceReview.new({
          :source => stories(:unreviewed_story).primary_source,
          :member => members(:trusted_member),
          :ratings => [Rating.new(:criterion => "trust", :value => 5)]})
        sr.save.should be(true)
      end.should change(SourceReview, :count)
      
      ratingless_review = Review.new(
        :member => members(:trusted_member),
        :story => stories(:unreviewed_story))
      ratingless_review.save_and_process_with_propagation.should be(true)

      ProcessJob.find(:all).map(&:process)
      
      stories(:unreviewed_story).reload.rating.should > old_rating
    end
    
    it "should not factor in reviews from suspended members" do
      # (first must force recalc of reviews)
      stories(:contentious_story).reviews.each{|r| r.save_and_process_with_propagation }
      
      # story rating includes untrustworthy member's input
      stories(:contentious_story).public_reviews.length.should eql(3)
      stories(:contentious_story).save_and_process_with_propagation.should be(true)
      old_rating = stories(:contentious_story).rating
      
      # now suspend untrustworthy member!
      members(:untrustworthy_member).status = "suspended"
      members(:untrustworthy_member).save.should be_true
      
      # review should now be hidden so story rating should change
      stories(:contentious_story).reload.public_reviews.length.should eql(2)
      stories(:contentious_story).save_and_process_with_propagation.should be(true)
      stories(:contentious_story).reload.rating.should_not eql(old_rating)
    end
    
  end
  
  describe "member transparency" do
    
    it "should penalize hidden profiles" do
      members(:legacy_member).save_and_process_with_propagation # populate transparency
      old_transparency_level = members(:legacy_member).reload.processed_rating("transparency")
      members(:legacy_member).show_profile = 'members'
      members(:legacy_member).save_and_process_with_propagation
      members(:legacy_member).reload.processed_rating("transparency").should < old_transparency_level
    end
    
  end
  
  describe "database internals" do
    it "should store processed ratings on updates, with no null-processable_id rows!" do
      2.times do # twice to check the _update_ case
        stories(:unreviewed_story).save_and_process_with_propagation
        ProcessedRating.count.should_not be_zero
        ProcessedRating.count(:conditions => {:processable_id => nil}).should be_zero
        ProcessedRating.count(:conditions => {:processable_id => stories(:unreviewed_story), :processable_type => Story.name}).should_not be_zero
      end
    end
    
    it "should only store historic rating values if they have changed since last save" do
      # assume no fixture data there
      ProcessedRatingVersion.count.should be_zero
      
      # first save: _should_ store a historic value
      lambda do
        stories(:unreviewed_story).save_and_process_with_propagation
      end.should change(ProcessedRatingVersion, :count).by(1)
      
      # subsequent save with no rating change: should _not_ store a historic value
      lambda do
        stories(:unreviewed_story).save_and_process_with_propagation
      end.should_not change(ProcessedRatingVersion, :count)
      
      # subsequent save _with_ rating change: _should_ store a historic value
      lambda do
        stories(:unreviewed_story).page_views_count = 100 # anything to change the rating
        stories(:unreviewed_story).save_and_process_with_propagation
      end.should change(ProcessedRatingVersion, :count).by(1)
    end
  end
end
