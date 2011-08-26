require File.dirname(__FILE__) + '/../spec_helper'

describe Tagging do
  fixtures :all

  it 'should find identical taggings' do
    t1 = Tagging.find(5)  #s2_on_t11
    t2 = t1.clone
    t1.equals(t2).should be_true

      # different ids are okay
    t2.save!
    t1.equals(t2).should be_true

      # different tags are not
    t2.tag = Tag.find(1)
    t1.equals(t2).should be_false

      # different taggable types are not
    t2.tag = t1.tag
    t2.taggable_type = 'Review'
    t1.equals(t2).should be_false

      # different member_ids are not
    t2.taggable_type = 'Story'
    t1.member_id = 1
    t2.member_id = 2
    t1.equals(t2).should be_false
  end
end
