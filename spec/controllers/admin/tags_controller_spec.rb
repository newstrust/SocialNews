require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::TagsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :all

  before(:each) do
    add_roles
  end
    
  def do_get(action = :index, opts = {})
    get action, opts
  end
    
  def do_post(action, opts = {})
    post action, opts
  end

  it "should require admin access to view GET /admin/tags" do
    should_be_admin_only do
      do_get
    end
    response.should be_success
  end

  it "should mass-tag stories" do
    t11 = Tag.find(11)  # source_tag
    t11_stories = Tagging.find_all_by_tag_id(11).collect { |t| t.taggable_id } # 2, 4

    t1 = Tag.find(1)  # target_tag
    t1_stories = Tagging.find_all_by_tag_id(1).collect { |t| t.taggable_id } # 3

    login_as 'admin'
    do_post(:add_mass_tags, {:source_tag => t11.name, :target_tag => t1.name })

    new_t1_stories = Tagging.find_all_by_tag_id(1).collect { |t| t.taggable_id }

      # All new_t11 stories should be present in t1 or t11
      # All stories in t1 and t11 should be present in new_t11
    (new_t1_stories - t11_stories - t1_stories).should == []
    (t1_stories - new_t1_stories).should == []
    (t11_stories - new_t1_stories).should == []

      # lengths should add up
    new_t1_stories.length.should == (t11_stories.length + t1_stories.length)
  end

  it "should mass-tag stories without assigning duplicate tags" do
    t11 = Tag.find(11)  # source_tag
    t11_stories = Tagging.find_all_by_tag_id(11).collect { |t| t.taggable_id } # 2, 4

    t12 = Tag.find(12)  # target_tag
    t12_stories = Tagging.find_all_by_tag_id(12).collect { |t| t.taggable_id } # 4, 5

    login_as 'admin'
    do_post(:add_mass_tags, {:source_tag => t11.name, :target_tag => t12.name })

    new_t12_stories = Tagging.find_all_by_tag_id(12).collect { |t| t.taggable_id }

      # All new_t12 stories should be present in t12 or t11
      # All stories in t12 and t11 should be present in new_t12
    (new_t12_stories - t11_stories - t12_stories).should == []
    (t12_stories - new_t12_stories).should == []
    (t11_stories - new_t12_stories).should == []

      # lengths should not add up because duplicate tagging is not done
    new_t12_stories.length.should < t11_stories.length + t12_stories.length
  end

  it "should mass-tag stories only within requested date range"
end
