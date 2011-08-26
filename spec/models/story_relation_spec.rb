require File.dirname(__FILE__) + '/../spec_helper'

describe StoryRelation do
  fixtures :all
  
  before(:each) do
    @legacy_member = members(:legacy_member)
    @legacy_story = stories(:legacy_story)
  end
end
