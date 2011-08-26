require File.dirname(__FILE__) + '/../spec_helper'

describe StoryUrl do
  fixtures :all
  
  it "should not allow alternate urls which belong to existing stories" do
    stories(:legacy_story).urls_attributes = [{"should_destroy" => "false", "url" => stories(:story_4).url}]
    stories(:legacy_story).save.should be_false
    stories(:legacy_story).errors.on(:urls).should_not be_nil
  end
end
