require File.dirname(__FILE__) + '/../spec_helper'

describe Source do
  fixtures :all

  it "should not allow blank slugs to be saved" do
    @s = Source.create(:name => 'foo', :slug => '')
    @s.valid?.should be_true
    @s.slug.should be_nil
    @s.update_attributes(:name => 'bar', :slug => '')
    @s.name.should == "bar"
    @s.slug.should be_nil
  end

  it "should not delete a source if it has stories attached to it" do
    @s = sources(:legacy_source)
    @s.destroy.should be_false
  end

  it "should delete a source if it has no stories attached to it" do
    @s = Source.find(1)
    @s.authorships_count.should == @s.authorships.length
    @s.authorships.each { |a| a.destroy }
    @s.reload.destroy.should_not be_false
  end

  it "should update stype_code of stories when ownership changes" do
    @s = Source.find(1)
    @s.stories.count.should > 1
    before = @s.stories.first.stype_code
    @s.update_attribute(:ownership, @s.ownership == Source::MSM ? Source::IND : Source::MSM)
    after = @s.stories.first.reload.stype_code
    before.should_not == after
  end

  it "should return the count of public stories"

  describe "merging" do
    before(:each) do
      @s1 = Source.find(1)
      @s2 = Source.find(2)
      @s4 = Source.find(4)
    end

    it 'should delete the dupe source' do
      lambda { Source.find(@s2.id) }.should_not raise_error(ActiveRecord::RecordNotFound)
      @s1.swallow_dupe(@s2)
      lambda { @s2.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end

    
    it 'should ensure that authorships_count is correct' do 
      n_a1 = @s1.authorships_count
      n_a2 = @s2.authorships_count

      @s1.swallow_dupe(@s2)
      @s1.reload.authorships_count.should == (n_a1 + n_a2)
    end

    it 'should ensure that is source_reviews_count correct'
    it 'should ensure that story_reviews_count is correct'
    it 'should merge authorships while ignoring dupes'
    it 'should merge source reviews while leaving dupe reviews with the dupe source'
    it 'should migrate source affiliations over to the new source'
  end
end
