require File.dirname(__FILE__) + '/../spec_helper'

describe LegacyTextParser do
  fixtures :all
  describe "LegacyTextParser.format_member_attribute_favorite_link()" do
     before(:each) do
       @member = members(:heavysixer)
     end
     it "should convert a string of links into a list of links" do
       @member.favorite_links.should == "<a href=\"http://www.google.com\">Google</a>\n<a href=\"http://www.yahoo.com\">Yahoo</a>\n<a href=\"http://www.locusfoc.us\">Locus Focus</a>\n\n"
       LegacyTextParser.format_member_attribute_favorite_link().should be_true
       @member.reload.favorite_links.should == "<ul><li><a href=\"http://www.google.com\">Google</a>\n<a href=\"http://www.yahoo.com\">Yahoo</a>\n<a href=\"http://www.locusfoc.us\">Locus Focus</a>\n\n</li></ul>"
       
       # It should not convert the text if it is already in a list.
       LegacyTextParser.format_member_attribute_favorite_link().should be_true
       @member.reload.favorite_links.should == "<ul><li><a href=\"http://www.google.com\">Google</a>\n<a href=\"http://www.yahoo.com\">Yahoo</a>\n<a href=\"http://www.locusfoc.us\">Locus Focus</a>\n\n</li></ul>"
     end
  end
  
  describe "LegacyTextParser.add_space_around_tags()" do
    it "should add a space to any nestled tag" do
      str = "This is a sentence that needs a space around this<a href='http://www.google.com/'>link</a> "
      str << "but not this <a href='http://www.yahoo.com'>one</a>."
      result = LegacyTextParser.add_space_before_tags(str)
      
      # should have added space here.
      result.should =~ /around this <a href/
      
      # but not here.
      result.should =~ /not this <a href/
    end
  end
  
  describe "LegacyTextParser.double_all_linebreaks()" do
    it "should double any single linebreak" do
      str = <<EOF
  this is some file
  with single linbreaks.
    
  Here is one that becomes two.
EOF
      result = LegacyTextParser.double_all_linebreaks(str)
      result.should =~ /\n\n/
    end

  end
end
