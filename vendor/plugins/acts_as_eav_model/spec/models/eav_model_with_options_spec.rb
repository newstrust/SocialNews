require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model annotated with 'has_eav_behavior' with options in declaration" do
  it "should be 'has_many' association on both sides" do
    Person.reflect_on_association(:preferences).macro.should == :has_many
    Person.reflect_on_association(:person_contact_infos).macro.should == :has_many
  end

  it "should only allow restricted fields when specified (:fields => %w(phone aim icq))" do
    p = Person.new :aim=>'example.aim', :phone=>'555-5555', :icq=>'example.icq'
    p.aim.should == 'example.aim'
    p.phone.should == '555-5555'
    p.icq.should == 'example.icq'
    lambda { p.doesnt_exist }.should raise_error(NoMethodError)
  end

  it "should raise 'NoMethodError' when attribute not in 'eav_attributes' method array" do
    p = Person.new :project_search=>'foo', :project_order=>'bar'
    p.project_search.should == 'foo'
    p.project_order.should == 'bar'
    lambda { p.project_blah }.should raise_error(NoMethodError)
  end

  it "should raise 'NoMethodError' when attribute does not satisfy 'is_eav_attribute?' method" do
    doc = Document.new
    doc.copyright_attr.should be_nil
    lambda { doc.no_exist }.should raise_error(NoMethodError)
  end
end
