require File.dirname(__FILE__) + '/../spec_helper'

describe StoriesHelper do
  include StoriesHelper
  it "should prioritize twitter feeds over other feeds"
  it "should prioritize all other feeds over facebook news feeds"
  it "should not show links to facebook news feeds"
end
