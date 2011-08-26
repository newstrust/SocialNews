require File.dirname(__FILE__) + '/../spec_helper'

describe Tag do
  fixtures :all
  describe 'being created' do
    before(:each) do
      @legacy_member = members(:legacy_member)
      @heavysixer = members(:heavysixer)
      @story  = stories(:legacy_story)
      @tag = tags(:whales)      
    end

    it "should allow tags on stories" do
      lambda do
        @story.tag_with('Foo', :member_id => @heavysixer)
      end.should change(Tag, :count)

      @story.tag_aggregate.should == "whales, Foo"
      
      t = Tag.find_by_name('Foo')
      @story.tags.include?(t).should be_true
    end

    it "should accept apostrophes in tags if the tag is double-quoted" do
      lambda do
        @story.tag_with("\"Alzheimer's Disease\"", :member_id => @heavysixer)
      end.should change(Tag, :count).by(1)
    end

    it "should not require a member_id to create a tag" do
      lambda do
        @story.tag_with('Foo', { :member_id => 1 })
      end.should change(Tag, :count)
    end
    
    it "should be able to optionally include a context" do
      lambda do
        @story.tag_with('Foo', :context => 'sekret')
      end.should change(Tag, :count)
      
      Tagging.find(:all, :conditions => ['context = ?', 'sekret']).should_not be_empty
    end
    
    it "should count taggings when created" do
      @story.tag_with('Barz', :member_id => @legacy_member)
      @story.tag_with('Barz', :member_id => @heavysixer)
      t = Tag.find_by_name('Barz')
      t.taggings_count.should == 2
      @story.untag_with('Barz', :member_id => @heavysixer)
      t = Tag.find_by_name('Barz')
      t.taggings_count.should == 1
    end
    
    it "should create many tags from a comma delimited string" do
      # Tag using a string of keywords
      lambda do
        tags = "apple, pear, orange"
        @story.tag_list = { :tags => tags, :member_id => @legacy_member.id }
        
        # Did we get out what we put in?
        all_tags = '"red cross", ' + tags   ## SSS: add "red cross" to the beginning, since tag_list= does not over-write tags
        @story.tags.each do |tag|
          (all_tags =~ /#{tag.name}/).should_not be_nil
          (@story.tag_aggregate =~ /#{tag.name}/).should_not be_nil
        end
      end.should change(Tag, :count).by(3)
    end

    it "should accept comma-holding tags from a comma delimited string" do
      @story.taggings.delete_all
      lambda do
        tags = "\"Obama, Barack\", \"Clinton, Hillary\""
        @story.tag_list_writer = { :tags => tags }
        
        # Did we get out what we put in?
        @story.tags.each do |tag|
          (@story.tag_aggregate =~ /#{tag.name}/).should_not be_nil
        end
      end.should change(Tag, :count).by(2)
    end
    
    it "should replace only the existing tags for that member" do
      @red_cross_tag = tags(:red_cross)
      @story.tags.include?(@red_cross_tag).should be_true
      @story.tags.include?(@tag).should be_true
      @story.tag_with('Foo', :member_id => @legacy_member)
      t = Tag.find_by_name('Foo')
      @story.tags.include?(t).should be_true
      
      # The tag no longer exists because the member overwrote it with the new tag.
      @story.tags.include?(@tag).should be_false
      
      # The red cross tag should remain because it was added by another member.
      @story.tags.include?(@red_cross_tag).should be_true
    end
    
    it "should not create a new tag if the story already contains that tag" do
      lambda do
        @story.tag_with(@tag.name, :member_id => @legacy_member)
      end.should_not change(Tag, :count)
      
      lambda do
        @story.tag_with(@tag.name, :member_id => @heavysixer)
      end.should_not change(Tag, :count)
    end
    
    it "should handle lists of tags using space and commas as a delimiter" do
      ['"ruby on rails", ruby', '"trains on rails" train'].each do |tags|
        lambda do
          @story.tag_list = { :tags => tags, :member_id => @legacy_member.id }
            
          # Do we get out what we put in?
          # Only test if original tag list had commas, b/c while we can accept both
          # commas and spaces as delimeters, we can only *outpout* one or the other.
          # We choose commas.
          if tags =~ /,/
            @story.tag_list.should =~ /#{tags}/
            @story.tag_aggregate.should =~ /#{tags}/
          end
        end.should change(Tag, :count).by(2)
      end
      
      @story.taggings.delete_all
      # Do the same thing, but this time w/ single quotes
      ["'foos on bars', foo", "'bars on foos' bar"].each do |tags|
      
        # Replace single quotes with double quotes since that is what the tagging does
        tags = tags.gsub(/'/, '"')
        lambda do
          @story.tag_list = { :tags => tags, :member_id => @legacy_member.id }      
          
          # Do we get out what we put in?
          # Only test if original tag list had commas, b/c while we can accept both
          # commas and spaces as delimeters, we can only *outpout* one or the other.
          # We choose commas.
          if tags =~ /,/
            tags.gsub(/'/, '"').should =~ /#{@story.tag_list}/
            tags.should =~ /#{@story.tag_aggregate}/
          end
        end.should change(Tag, :count).by(2)
      end
    end
  end
  
  describe 'being accessed' do
    before(:each) do
      @legacy_member = members(:legacy_member)
      @heavysixer = members(:heavysixer)
      @story  = stories(:legacy_story)
      @red_cross_tag = tags(:red_cross)
      @tag = tags(:whales)
    end
    
    it "should allow members to see a list of their own tags" do
      @heavysixer.my_tags.include?(@red_cross_tag).should be_true
      @heavysixer.my_tags.include?(@tag).should be_false
    end
    
    it "should allow members to see their tags on a particular story" do
      @story.tags.include?(@red_cross_tag).should be_true
      @story.tags.include?(@tag).should be_true
      @heavysixer.my_tags_for(@story).include?(@red_cross_tag).should be_true
      
      # Even though the story contains this tag the member was not the one who created it
      @heavysixer.my_tags_for(@story).include?(@tag).should be_false
    end
  end
  
  describe 'being deleted' do
    before(:each) do
      @legacy_member = members(:legacy_member)
      @heavysixer = members(:heavysixer)
      @story  = stories(:legacy_story)
      @red_cross_tag = tags(:red_cross)
      @tag = tags(:whales)
      @story.taggings.delete_all
      @tags = "apple, grapes, oranges"
      
      # Used to disable the need for running the Sphinx daemon.
      ThinkingSphinx::Search.stub!(:search_for_id).and_return(false)
      
      lambda do
        lambda do
          @story.tag_list = { :tags => @tags, :member_id => @heavysixer.id }
        end.should change(Tagging, :count).by(3)
      end.should change(Tag, :count).by(3)
      
      # Ensure the tag count does not increase when the same tag is applied by another member
      lambda do
        lambda do
          @story.tag_list = { :tags => @tags, :member_id => @legacy_member.id }
        end.should change(Tagging, :count).by(3)
      end.should_not change(Tag, :count)
    end
    
    it "should not require a member_id to delete a tag" do
      lambda do
        @story.tag_with('Foo')
      end.should change(Tag, :count)
      
      lambda do
        @story.untag_with('Foo')
      end.should change(Tag, :count).by(-1)
    end

    it "should get equal-opportunity deletion service if it has commas" do
      lambda do
        @story.tag_with('"Daggett, Mark"')
      end.should change(Tag, :count).by(1)

      lambda do
        @story.untag_with('"Daggett, Mark"')
      end.should change(Tag, :count).by(-1)
    end
    
    it "should update tag_aggregate when deleting a tag" do
      lambda do
        @story.tag_with('Foo')
      end.should change(@story, :tag_aggregate)
      
      lambda do
        @story.untag_with('Foo')
      end.should change(@story, :tag_aggregate)
    end
    
    it "should allow members to untag their items" do
      # Ensure that the Tag count does not change even though a member removed their tags,
      # because those same tags are still used by another member.
      lambda do
        lambda do
          @story.untag_with(@tags, :member_id => @heavysixer.id)
        end.should change(Tagging, :count).by(-3)
      end.should_not change(Tag, :count)

      # Now outright delete the tags
      lambda do
       records = Tag.find(:all, :conditions => ['name in (?)', @tags.split(', ')])
        
        # Ensure delete takes a array
        @story.tags.delete(records[0..1], @legacy_member.id)
        
         # Ensure delete takes a single item
         @story.tags.delete(records[2], @legacy_member.id)
      end.should change(Tagging, :count).by(-3)
    end
    
    it "should not delete tags when invalid arguments are supplied" do
      lambda do
        lambda do
          @story.tags.delete('invalid tag', @legacy_member.id)
        end.should_not change(Tag, :count)
      end.should_not change(Tagging, :count)
    end
    
    it "should delete the tag when the last tagging is removed" do
      @story.tag_with('Barz', :member_id => @heavysixer)
      t = Tag.find_by_name('Barz')
      t.taggings_count.should == 1
      @story.untag_with('Barz', :member_id => @heavysixer)
      Tag.find_by_name('Barz').should be_nil
    end
    
  end
end
