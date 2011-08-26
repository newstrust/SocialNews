require File.dirname(__FILE__) + '/../spec_helper'

describe Topic do
  fixtures :all

  it 'should identify high-volume topics' do
    env = Topic.find_by_slug("environment")
    env.topic_volume = SocialNewsConfig["high_volume_topic_days"]
    env.save!
    env.is_high_volume?.should be_true
    env.topic_volume = SocialNewsConfig["high_volume_topic_days"] + 1
    env.save!
    env.is_high_volume?.should be_false
  end

  it 'should find the featured topic' do
    Topic.featured_topic.should_not be_nil
  end

  describe 'being created' do
    it "should create a topic and use the name for a slug unless a slug is provided" do
      lambda do
        @topic = Topic.create(:name => "some long name")
      end.should change(Topic, :count).by(1)
      @topic.slug.should == "some-long-name"
    end
    
    it "should create a topic and use a slug if one is provided" do
      lambda do
        @topic = Topic.create(:name => "some long name", :slug => 'foo bar baz')
      end.should change(Topic, :count).by(1)
      @topic.slug.should == "foo-bar-baz"
    end
  end  

  describe 'being searched' do
    it "should return only topics" do
      t = Topic.find(:first)
      ThinkingSphinx.stub!(:search).and_return(t)
      @results = Topic.search(t.name)
      @results[0].class.should == t.class
    end
  end

  describe 'when renamed' do
    before(:each) do
      @topic = topics(:politics)
      # @tag = @topic.tag is not kosher because @tag.reload later on points @tag to the new tag whereas I want the original tag!
      @tag = Tag.find(@topic.tag_id)
    end

    it "should rename underlying tag if there is no other tag with that name" do
      @topic.update_attribute(:name, "politics_new")
      @topic.reload
      @tag.reload
      @tag.should == @topic.tag
      @tag.name.should == @topic.name # renaming of existing tag
    end

    it "should switch underlying tag if there is another tag with that name" do
      n = @tag.name
      t_new = Tag.create(:name => "politics_new")
      @topic.update_attribute(:name, "politics_new")
      @topic.reload
      @tag.reload
      @tag.name.should == n           # no renaming of existing tag
      @tag.should_not == @topic.tag   # switch of underlying topic tag
      t_new.should == @topic.tag
    end

    it "should downgrade original underlying tag when possible" do
      n = @tag.name
      t_new = Tag.create(:name => "politics_new")
      @topic.update_attribute(:name, "politics_new")
      @topic.reload
      @tag.reload
      @tag.tag_type.should be_nil
    end

    it "should not downgrade original underlying tag when not possible" do
      n = @tag.name
      t_new = Tag.create(:name => "politics_new")
      # Create a new topic that points to the underlying tag
      Topic.create(:name => n, :local_site_id => 1, :tag_id => @tag.id)
      @topic.update_attribute(:name, "politics_new")
      @topic.reload
      @tag.reload
      @tag.tag_type.should_not be_nil
    end
  end

  describe 'being edited' do
    it "should add or remove subjects" do
      @politics = topics(:politics)
      @human_rights = topics(:human_rights)
      lambda do
        @human_rights.subjects.add(@politics, @politics.grouping(@politics.groupings.first))
      end.should change(@human_rights.subjects(true), :size).by(1)
      
      lambda do
        @human_rights.subjects.remove(topics(:health))
      end.should raise_error(ActiveRecord::RecordNotFound)
      
      lambda do
        @human_rights.subjects.remove(@politics)
      end.should change(@human_rights.subjects(true), :size).by(-1)
    end
    
    it "should allow you to mass add or delete subjects with an optional grouping" do
      @human_rights = topics(:human_rights)
      @params = { "world" => "0", "politics" => "1", "us" => "0", "health" => "1" }
      lambda do
        # add health
        # remove world
        # add politics
        @human_rights.subjects.update(@params)
      end.should change(@human_rights.subjects(true), :size).by(1)
      
      @params = { "world" => "1", "politics" => "0", "us" => "1", "health" => "0" }
      @params["grouping"] = { "world" => "world_countries", "us" => "" }
      lambda do
        # add us
        # remove health
        # add world with a grouping of world_countries
        # remove politics
        @human_rights.subjects.update(@params)
      end.should change(@human_rights.subjects(true), :size).by(0)
      @human_rights.topic_relations.map{|x| x.grouping}.include?("world_countries").should be_true
      
      @params["grouping"] = { "world" => "worldwide_topics", "us" => "" }
      
      # Now just update a grouping without adding or removing
      lambda do
        @human_rights.subjects.update(@params)
      end.should change(@human_rights.subjects(true), :size).by(0)
      @human_rights.topic_relations(true).map { |x| x.grouping }.include?("world_countries").should be_false
      @human_rights.topic_relations.map{|x| x.grouping}.include?("worldwide_topics").should be_true
      
    end
  end
end
