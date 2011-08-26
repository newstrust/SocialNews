require File.dirname(__FILE__) + '/../spec_helper'

describe Story do
  fixtures :all

  it "should maintain stype constants in a certain relationship" do
    # update_story_types in source.rb requires this relationship to be maintained
    (Story::IND_NEWS - Story::MSM_NEWS).should == (Story::IND_OPINION - Story::MSM_OPINION)
  end

  describe "site membership" do
    it "should return true for new stories on the national site" do
      Story.new.belongs_to_site?(nil).should == true
    end
    
    it "should return true for existing stories on the national site" do
      s = Story.find(:last)
      s.belongs_to_site?(nil).should == true
    end

    it "should return false for stories that dont have a local site's tagging" do
      s = Story.find(:last)
      s.taggings = []
      l = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
      s.belongs_to_site?(l).should == false
    end

    it "should return true for existing stories on the national site that also belongs to a local site" do
      l = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
      s = Story.find(:last)
      s.taggings << Tagging.new(:tag_id => l.constraint_id)
      s.save!
      s.reload
      s.belongs_to_site?(l).should == true
      s.belongs_to_site?(nil).should == true
    end
  end

  describe "attribute tests" do
    it 'should identify story topics and story subjects' do
      Story.find(2).topic_tags.should   == []
      Story.find(4).topic_tags.should   == [Topic.find(3).tag]

      Story.find(2).subject_tags.should == [Topic.find(11).tag]
      Story.find(4).subject_tags.should == [Topic.find(11).tag, Topic.find(12).tag]
    end

    it 'should identify story type (news/opinion)' do
      Story.find(1).is_news.should be_true
      Story.find(3).is_opinion.should be_true
      Story.find(4).is_opinion.should be_false
      Story.find(5).is_news.should be_false
    end

    it 'should identify the primary_source' do
      Story.find(1).primary_source.should == Source.find(1)
      Story.find(4).primary_source.should == Source.find(3)
      Story.find(6).primary_source.should == Source.find(2)
    end

    it 'should set cached and computed values on story save' do
      s = Story.find(1)
      s.primary_source_medium.should be_nil
      s.save!
      s.primary_source_medium.should == "newspaper"

      s = Story.new(:url => "http://abcdefgh", :title => "dummy title", :story_type => "news_report");
      alternet = Source.find_by_slug("alternet")
      s.authorships << Authorship.new(:source => alternet)
      s.rating = 1.0
      s.story_date = Time.now
      s.save!
      s.stype_code.should == Story::IND_NEWS
      s.primary_source_id.should == alternet.id
      s.primary_source_medium.should == "newspaper"
    end

    it 'should not let story dates be dates in the future' do
      s = Story.find(1)
      s.story_date = Time.now + 5.days
      s.save!
      s.story_date.beginning_of_day.should == Time.now.beginning_of_day
    end
  end

  describe "tagging" do
    before(:each) do
      @story = Story.find(1)
      @story.taggings = []
      @story.reload
      @topic = Topic.find(1)
      @topic.subjects.length.should > 0
      @story.taggings << Tagging.new(:tag => @topic.tag, :member_id => Member.nt_bot)
    end

    describe "when inferring new matching subject tags," do
      it "should add new db-commited subject taggings if the new tagging is in the db" do
        new_taggings = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
        new_taggings.length.should > 1 # More than 1 db taggings
        (new_taggings.map(&:tag) - @topic.subjects.map(&:tag)).should == []
        (@topic.subjects.map(&:tag) - new_taggings.map(&:tag)).should == []
      end

      it "should add new subject taggings that are in-memory but NOT in the db if the new tagging is NOT in the db" do
        @story.taggings = []
        @story.taggings.build(:tag => @topic.tag, :member_id => Member.nt_bot)
        @story.taggings.length.should > 1 # More than 1 in-memory tagging
        Tagging.find(:all, :conditions => {:taggable_id => @story.id, :taggable_type => "Story"}).should == [] # No in-db taggings!
        (@story.taggings.map(&:tag) - [@topic.tag]).sort { |a,b| a.name <=> b.name}.should == @topic.subjects.map(&:tag).sort{ |a,b| a.name <=> b.name} # But, new subject taggings should be present
      end
    end

    it "should remove an auto-inferred matching subject tag when a member adds a subject tag" do
      t1 = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      @story.taggings << Tagging.new(:tag => @topic.subjects[0].tag, :member_id => Member.nt_anonymous)
      t2 = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (t1 - t2).map(&:tag).should == [@topic.subjects[0].tag]
    end

    it "should remove no-long-valid auto-inferred subject tags when a member removes a topic tag (via tag_list= method)" do
      # Make sure our fixtures are such that t2 and t1 share a subject, but aren't all the same!
      topic2 = Topic.find(2)
      topic2.subjects.length.should > 0
      diff = @topic.subjects - topic2.subjects
      diff.length > 0
      diff.length < @topic.subjects.length

      # Add the second tag
      @story.taggings << Tagging.new(:tag => topic2.tag, :member_id => Member.nt_bot)
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == [] # All of @topic's exclusive subjects should be auto-tagged

      # Reload to get all the latest taggings! 
      @story.reload

      # Retag with only the 2nd topic!
      @story.tag_list= {:tags => "\"#{topic2.name}\"", :member_id => Member.nt_bot.id}

      # Verify that the first tag's exclusive subjects have been removed!
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == diff.map(&:tag) # All of @topic's exclusive subjects from nt_tagger should have been removed!

      # Overall subject tags should be the same as from topic2
      (@story.reload.subject_tags - topic2.subjects.map(&:tag)).length.should == 0
    end

    it "should remove no-long-valid auto-inferred subject tags when a member removes a topic tag (via association_collection.destroy method)" do
      # Make sure our fixtures are such that t2 and t1 share a subject, but aren't all the same!
      topic2 = Topic.find(2)
      topic2.subjects.length.should > 0
      diff = @topic.subjects - topic2.subjects
      diff.length > 0
      diff.length < @topic.subjects.length

      # Add the second tag
      @story.taggings << Tagging.new(:tag => topic2.tag, :member_id => Member.nt_bot)
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == [] # All of @topic's exclusive subjects should be auto-tagged

      # Reload to get all the latest taggings! 
      @story.reload

      # Delete the first topic tagging
      t = @story.taggings.find_all_by_tag_id(@topic.tag.id).first
      @story.taggings.delete(t)
      t.destroy

      # Verify that the first tag's exclusive subjects have been removed!
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == diff.map(&:tag) # All of @topic's exclusive subjects from nt_tagger should have been removed!

      # Overall subject tags should be the same as from topic2
      (@story.reload.subject_tags - topic2.subjects.map(&:tag)).length.should == 0
    end

    it "should remove invalid auto-inferred subject tags when a member removes a topic tag without touching member-added subject tags" do
      # Make sure our fixtures are such that t2 and t1 share a subject, but aren't all the same!
      topic2 = Topic.find(2)
      topic2.subjects.length.should > 0
      diff = @topic.subjects - topic2.subjects
      diff.length > 0
      diff.length < @topic.subjects.length

      # Add the second tag
      @story.taggings << Tagging.new(:tag => topic2.tag, :member_id => Member.nt_bot)
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == [] # All of @topic's exclusive subjects should be auto-tagged

      # Reload to get all the latest taggings!
      @story.reload

      # Retag with only the 2nd topic!
      @story.tag_list = {:tags => "\"#{topic2.name}\"", :member_id => Member.nt_bot.id}

      # Now, add subject tags from diff from a different member
      diff.each { |s| @story.taggings << Tagging.new(:tag => s.tag, :member_id => Member.nt_anonymous) }

      # Verify that the first tag's exclusive subjects have been removed, but all the subject tags remain intact
      ts = Tagging.find(:all, :conditions => {:member_id => Member.nt_tagger.id, :taggable_id => @story.id, :taggable_type => "Story"})
      (diff.map(&:tag) - ts.map(&:tag)).should == diff.map(&:tag) # All of @topic's exclusive subject taggings from nt_tagger should have been removed!

      # Overall subject tags should continue to have additional subject tags from diff
      (@story.reload.subject_tags - topic2.subjects.map(&:tag)).length.should > 0
      (@story.reload.subject_tags - topic2.subjects.map(&:tag) - diff.map(&:tag)).length.should == 0
    end
  end

  describe "scope" do
    before :each do 
      @s = Story.find(6)
      @s.update_attribute(:is_local, nil)
    end

    it "should be 'not_sure' if the is_local flag is not set" do
      @s.story_scope.should == "not_sure"
    end

    it "should be correct if the is_local flag is set" do
      @s.update_attribute(:is_local, true)
      @s.story_scope.should == Story::StoryScope::LOCAL
      @s.update_attribute(:is_local, false)
      @s.story_scope.should == Story::StoryScope::NATIONAL
    end
  end

  describe "set_story_scope should set is_local flag to" do
    before :each do 
      @s = Story.find(6)
      @s.update_attribute(:is_local, nil)
    end

    it "true if arg is 'local" do
      @s.set_story_scope("local")
      @s.is_local.should == true
    end

    it "false if arg is 'national" do
      @s.set_story_scope("national")
      @s.is_local.should == false
    end

    it "true if arg is 'not_sure' and it has a local subject" do
      @s.taggings << Tagging.new(:tag => Subject.find_by_slug("local").tag)
      @s.set_story_scope("not_sure")
      @s.is_local.should == true
    end

    it "false if arg is 'not_sure' and it does not have a local subject" do
      @s.taggings = []
      @s.set_story_scope("not_sure")
      @s.is_local.should == false
    end

    it "true if arg is 'not_sure' and is set from a local site" do
      @s.taggings = []
      @s.set_story_scope("not_sure", LocalSite.new)
      @s.is_local.should == true
    end
  end

  describe "duplicate story detection" do
    before :each do 
      @s = Story.find(6)
    end

    it 'should find stories with identical urls' do
      dup = Story.check_for_duplicates(@s.url)
      dup.should == @s
    end

    it 'should ignore referral param for washpo stories' do
      orig_url = @s.url
      new_url  = orig_url + "?referrer=#{SocialNewsConfig["app"]["slug"]}"
      @s.url   = new_url
      @s.save!

      dup = Story.check_for_duplicates(orig_url)
      dup.should == @s
    end

    it 'should use referral param url as the canonical version of the url for washpo stories' do
      orig_url = @s.url
      new_url  = orig_url + "?referrer=#{SocialNewsConfig["app"]["slug"]}"
      dup = Story.check_for_duplicates(new_url)
      dup.should == @s
      @s.reload.url.should == new_url
    end
  end

#  describe 'member_posts_or_reviews named scope' do
#    before(:each) do
#      d = Time.now
#      Story.find(:all).each { |s| s.story_date = d; s.save! } # Make them all recent
#      @m11 = Member.find(11)
#    end
#
#    it 'should fetch stories reviewed by member' do
#      reviews = @m11.reviews.map(&:story_id)
#      mpr     = Story.member_posts_stars_reviews(@m11.id, Time.now - 10.days).map(&:id)
#      reviews.length.should > 0
#      mpr.length.should > 0
#      (reviews - mpr).length.should == 0
#    end
#
#    it 'should fetch stories posts by member when they are also reviewed by the member' do
#      mpr = Story.member_posts_stars_reviews(@m11.id, Time.now - 10.days).map(&:id)
#      mpr.length.should > 0
#      (mpr - [1]).length.should == (mpr.length - 1)
#    end
#
#    it 'should fetch stories posts by member when they are not reviewed by the member' do
#      mpr = Story.member_posts_stars_reviews(@m11.id, Time.now - 10.days).map(&:id)
#      mpr.length.should > 0
#      (mpr - [3]).length.should == (mpr.length - 1)
#    end
#  end

  describe "listings" do
    before(:each) do
      @options = { :time_span => 1.year }
      t = Time.now
      Story.find(:all, :order => "story_date ASC, id ASC").each_with_index { |s, i| s.update_attribute(:story_date, Time.now - 1.month + i.days) }
    end

    def get_opts_with_filters(filters)
      @options.merge!({:filters => filters})
    end

    def get_ids(stories)
      stories.map(&:id)
    end

    it 'should properly process topic filters' do 
      filters = { :topic => "john_mccain" }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [4]
    end

    it 'should properly process subject filters' do 
      filters = { :topic => "world" }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6, 3]
    end

    it 'should find stories by story type' do 
      filters = { :story_type => Story::OPINION }
      @options.merge!(get_opts_with_filters(filters))
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6,5,3]
    end

    it 'should respect the nolocal filter' do
      filters = { :story_type => Story::OPINION, :no_local => true }
      Story.update_all({:is_local => false})
      Story.find(6).update_attribute(:is_local, true)
      @options.merge!(get_opts_with_filters(filters))
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5,3]
    end

    it 'should find stories by source ownership' do 
      filters = { :sources => { :ownership => Source::IND } }
      @options.merge!(get_opts_with_filters(filters))
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5,4]
    end

    it 'should find stories by source ownership and story type' do 
      filters = { :story_type => Story::OPINION, :sources => { :ownership => Source::IND } }
      @options.merge!(get_opts_with_filters(filters))
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5]

      filters = { :story_type => Story::NEWS, :sources => { :ownership => Source::MSM } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [2,1]
    end

    it 'should find stories by source' do 
      filters = { :sources => { :slug => "alternet" } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5,4]
    end

    it 'should ignore source rating & status when fetching by source' do 
      alternet = Source.find_by_slug("alternet")
      alternet.status = 'hide'
      alternet.rating = '2.0'
      alternet.save!
      filters = { :sources => { :slug => "alternet" } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5,4]
    end

    it 'should find hidden stories' do
      filters = { :sources => { :slug => "washington_post" } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6]
    end

    it 'should find stories by editorial_status' do
      filters = { :sources => { :slug => "washington_post" }, :status => 'hide' }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [7]

      filters = { :sources => { :slug => "washington_post" }, :status => ['list'] }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6]

      filters = { :sources => { :slug => "washington_post" }, :status => ['hide','list'] }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [7,6]
    end

    it 'should find stories by editorial_priority' do
      filters = { :min_editorial_priority => 5 }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5]
    end

    it 'should find stories with minimum submitter level' do
      filters = { :min_submitter_level => 5 }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [2]
      filters = { :min_submitter_level => 4 }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6,5,4,2]
    end

    it 'should enforce source uniqueness constraint, if requested' do 
      filters = { :sources => { :max_stories_per_source => 1 } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [6,5,3]
    end

    it 'should exclude sources, if requested' do 
      filters = { :sources => { :exclude_ids => [1,2] } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5,4]
    end

    it 'should exclude sources if requested and enforce source uniqueness if requested' do 
      filters = { :sources => { :exclude_ids => [1,2], :max_stories_per_source => 1 } }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [5]
    end

    it 'should ignore story status' do
      filters = { :sources => { :slug => "washington_post" }, :ignore_story_status => true }
      stories = Story.list_stories(get_opts_with_filters(filters))
      get_ids(stories).should == [7,6]
    end

    it 'should find most recent when no listing type is provided' do
      stories = Story.list_stories(@options)
      get_ids(stories).should == [6,5,4,3,2,1]
    end

    it 'should find most recent stories' do
      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,5,4,3,2,1]
    end

    it 'should not ignore queued and hidden stories in regular listings' do
      s5 = Story.find(5)
      s5.status = Story::QUEUE
      s5.save!
      s3 = Story.find(3)
      s3.status = Story::HIDE
      s3.save!
      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,4,2,1]
    end

    it 'should find stories within a provided date range' do
      t = Time.now
      Story.find(:all).each { |s| s.update_attribute(:story_date, t - s.id.days) }
      stories = Story.list_stories({:listing_type => :most_recent, :start_date => t-5.days, :end_date => t-2.days})
      get_ids(stories).should == [2,3,4,5]
      stories = Story.list_stories({:listing_type => :most_recent, :start_date => t-2.months, :end_date => t-1.month})
      get_ids(stories).should == []
    end

    it 'should find most trusted stories' do
        # Reset all dates to y'day
      Story.find(:all).each { |s| s.story_date = Time.now-1.day; s.save! }
      stories = Story.list_stories({:listing_type => :most_trusted})
      get_ids(stories).should == [6,4,5]
    end

    it 'should not include sub-3.0 rating stories in top stories listings' do
      s = Story.find(4)
      s.rating = 2.5
      s.save!

      Story.find(4).sort_rating.should == 2.5

      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,5,3,2,1]
    end

    it 'should not include unrated stories from untrusted sources in top stories listings' do
      alternet = Source.find(3)
      alternet.rating = 2.5
      alternet.save!

      # work around attr_readonly for reviews_count counter_cache
      # update this field before editorial priority
      Story.update_all("reviews_count = 2", :id => 4)

      s = Story.find(4)
      s.editorial_priority = 2
      s.save!

      s.reload
      s.reviews_count.should == 2
      s.sort_rating.should < 1.0

      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,5,3,2,1]
    end

    it 'should not include unrated stories from unrated sources in top stories listings' do
      alternet = Source.find(3)
      alternet.authorships_count = 2
      alternet.save!

      # work around attr_readonly for reviews_count counter_cache
      # update this field before editorial priority
      Story.update_all("reviews_count = 2", :id => 4)

      s = Story.find(4)
      s.editorial_priority = 2
      s.save!
      
      s.reload
      s.reviews_count.should == 2
      s.sort_rating.should < 1.0

      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,5,3,2,1]
    end

    it 'should support paging options' do
      stories = Story.list_stories(@options.merge({:per_page => 2}))
      get_ids(stories).should == [6,5]

      stories = Story.list_stories(@options.merge({:page => 3, :per_page => 2}))
      get_ids(stories).should == [2,1]
    end

    it 'should find stories for review' do
      stories = Story.list_stories({:listing_type => :for_review})
      get_ids(stories).should == [3,2,1]
    end

    it 'should not include stories with sub 3.0 editorial priority in for-review listings for homepage' do
      s3 = Story.find(3)
      s3.editorial_priority = 2
      s3.save!

      opts = get_opts_with_filters({ :sources => { :max_stories_per_source => 1 } }).merge({:listing_type => :for_review})
      stories = Story.list_stories(opts)
      get_ids(stories).should == [2]
    end

    it 'listings should not include stories from hidden sources' do
      s6_source = Story.find(6).primary_source
      s6_source.status = 'hide'
      s6_source.save!
      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [5,4,3,2,1]
    end

    it 'listings should not ignore stories from pending sources' do
      s6_source = Story.find(6).primary_source
      s6_source.status = 'pending'
      s6_source.save!
      stories = Story.list_stories({:listing_type => :most_recent})
      get_ids(stories).should == [6,5,4,3,2,1]
    end

    it 'should test some more combinations of listing filters'
  end

  describe "merging" do
    before(:each) do
      @s1 = Story.find(1)
      @s2 = Story.find(2)
      @s3 = Story.find(3)
      @s4 = Story.find(4)
      @m1 = members(:heavysixer)
      @m2 = members(:legacy_member)
    end

    it 'should hide the dupe story' do
      @s1.swallow_dupe(@s2.id, members(:legacy_member))
      @s2.reload.status.should == 'hide'
    end

    it "should update story relations correctly" do
      @s1.related_stories.collect { |s| s.id }.should == [2]
      @s3.related_stories.collect { |s| s.id }.should == [2]
      @s1.swallow_dupe(@s2.id, members(:legacy_member))
      @s1.reload.related_stories.collect { |s| s.id }.should == [4]
      @s3.reload.related_stories.collect { |s| s.id }.should == [1]
    end

    it 'should not merge authorships' do
      a1 = @s1.sources.clone
      a2 = @s2.sources.clone
      @s1.swallow_dupe(@s2.id, members(:legacy_member))
      @s2.reload.sources.should == a2
      @s1.reload.sources.should == a1
    end

    it 'should merge reviews while leaving dupe reviews with the dupe story' do
      a1 = @s1.reviews.clone
      a2 = @s2.reviews.clone
      a1.length.should == 2
      a2.length.should == 1
      @s2.swallow_dupe(@s1, members(:legacy_member))

        # One review should be moved from s1 to s2, and one should be left behind!
      s1_reviews = @s1.reviews(true)
      s2_reviews = @s2.reviews(true)
      s1_reviews.length.should == 1
      s2_reviews.length.should == 2

        # The review left behind in s1 should have a member id that is already present in s2's reviews!
      s1_reviews_member_ids = s1_reviews.collect { |r| r.member_id }
      s2_reviews_member_ids = s2_reviews.collect { |r| r.member_id }
      ((s1_reviews_member_ids + s2_reviews_member_ids).uniq - s2_reviews_member_ids).should == []   # simulating set union and set equality here
    end

    it 'should ensure that reviews_count is correct if the dupe has a non-public review' do
        # Convert m2 to a regular member so that when we assign a review to m2, the review gets counted (guest reviews are not counted)
      m2 = Member.find(12)
      m2.status = 'member'
      m2.save!

        # Assign story_2_review to a different member so that when we merge story 2 with story 1, it won't be a dupe review! 
      x = reviews(:story_2_review)
      x.member_id=12
      x.save!
      s2 = @s2.reload
      s2.reviews.length.should == 1
      s2.reload.reviews_count.should == 1

        # Now mark x hidden -- we want to test whether reviews_count is adjusted when @s1 swallows @s2
      x.status = 'hide'
      x.save!
      s2 = @s2.reload
      s2.reviews.length.should == 1
      s2.reload.reviews_count.should == 0

        # Now swallow s2 into s1
      @s1.swallow_dupe(@s2, members(:legacy_member))
      s1 = @s1.reload
      s2 = @s2.reload
      s1.reviews.length.should == 3
      s1.reviews_count.should  == 2
      s2.reviews.length.should == 0
      s2.reviews_count.should  == 0
    end

    it 'should merge taggings without introducing dupes' do
      t2_count = @s2.tags.length  # has tag t11
      t4_count = @s4.tags.length  # has tags t3 & t11
      @s2.swallow_dupe(@s4.id, members(:legacy_member))    # s2 should now have t3 & t11
      @s2.reload.tags.length.should > t2_count
      @s2.reload.tags.length.should < (t2_count + t4_count)
    end
    
    it "should store the dupe story's URL" do
      dupe_url = @s2.url
      @s1.swallow_dupe(@s2.id, members(:legacy_member))
      Story.check_for_duplicates(dupe_url).id.should be(@s1.id)
    end

    it "should delete the dupe if urls are identical" do
        # clone s1 taking care to clear out fields that will interfere with story save & story merging
      s2 = @s1.clone
      s2.id = nil
      s2.legacy_id = nil
      s2.saves_count = 0
      s2.save(false)

      # work around attr_readonly for reviews_count counter_cache
      Story.update_all("reviews_count = 0", :id => s2.id)

      ActivityEntry.create(:member_id => @m1.id, :activity_type => 'Story', :activity_id => @s1.id)
      ae = ActivityEntry.create(:member_id => @m2.id, :activity_type => 'Story', :activity_id => s2.id)
      ActivityEntry.find(ae.id).should_not be_nil

        # Now attempt a swallow
      @s1.swallow_dupe(s2.id, members(:legacy_member))

        # s2 shouldn't be found!
      lambda { ActivityEntry.find(ae.id) }.should raise_error(ActiveRecord::RecordNotFound)
      lambda { Story.find(s2.id) }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
