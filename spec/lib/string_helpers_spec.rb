require File.dirname(__FILE__) + '/../spec_helper'

describe StringHelpers do
  describe "truncate" do
    before(:each) do
      @str = "It should truncate strings to specified lengths"
    end

    it 'should truncate strings only on word boundaries when possible, while returning the longest strings possible' do
      StringHelpers.truncate(@str, 5, 25).should == "It should truncate ..."
    end

    it 'should truncate strings to specified lengths even if not on word boundaries' do
      StringHelpers.truncate(@str, 25, 25).should == "It should truncate s- ..."
    end

    it 'should return nil if we insist on word boundary truncation when it is not possible' do
      StringHelpers.truncate(@str, 25, 25, true).should be_nil
    end

    it 'should not append a trailing ellipsis if we don\'t want it' do
      StringHelpers.truncate(@str, 25, 25, false, 0, false).should == "It should truncate strin-"
    end

    it 'should process a substring when asked to' do
      StringHelpers.truncate(@str, 8, 10, false, 10, false).should == "truncate"
    end
  end

  describe "truncate_on_word_boundary" do
    before(:each) do
      StringHelpers.separators = /\s/  ## All tests expect this
      @s1 = "It should truncate strings to specified lengths"
      @s2 = "the please-understand-we-were-just-doing-all-we-could-to-prevent-a-second-wave-of-attacks excuse for torture is bogus"
      @s3 = "the please-understand-we-were-just-doing-all-we-could-to-prevent-a-second-wave-of-attacks"
    end

    it 'should truncate strings on word boundaries only, while returning the longest strings possible' do
      StringHelpers.truncate_on_word_boundary(@s1, 0, 25).should == "It should truncate ..."
      StringHelpers.truncate_on_word_boundary(@s2, 0, 80).should == "the ..."
      StringHelpers.truncate_on_word_boundary(@s2, 10, 95).should == "the please-understand-we-were-just-doing-all-we-could-to-prevent-a-second-wave-of-attacks ..."
    end

    it 'should return nil if not possible to truncate on word boundaries and return at least a minimum length string' do
      StringHelpers.truncate_on_word_boundary(@s2, 10, 80).should be_nil
    end

    it 'should spillover to a string larger than requested, if spillover is permitted, but otherwise not possible to truncate on a word boundary' do
      StringHelpers.truncate_on_word_boundary(@s2, 10, 80, true).should == "the please-understand-we-were-just-doing-all-we-could-to-prevent-a-second-wave-of-attacks..."
    end

    it 'should return the entire string, if spillover is permitted, and no good word boundary exists' do
      StringHelpers.truncate_on_word_boundary(@s3, 10, 80, true).should == @s3
    end

    it 'should handle separators other than white-space' do
      StringHelpers.truncate_on_word_boundary(@s2, 0, 80).should == "the ..."
      StringHelpers.separators = /\s|-/
      StringHelpers.truncate_on_word_boundary(@s2, 0, 80).should == "the please-understand-we-were-just-doing-all-we-could-to-prevent-a-second ..."
    end
  end

  describe "linewrap_text" do
    before(:each) do
      @s1 = "abcd efgh ijkl mn op qrst uv wxyz. The quick brown fox jumps over the lazy dog. zyx wvu tsrq ponmlk jihgfe dcb a."
      @s2 = "abcd efgh ijkl mn op qrst uv wxyz.\n\nThe quick brown fox jumps over the lazy dog.\n\nzyx wvu tsrq ponmlk jihgfe dcb a."
    end

    it 'should wrap lines to max-length' do
      nt1 = StringHelpers.linewrap_text(@s1, 20)
      l1 = nt1.split("\n")
      l1.each {|l| l.length.should <= 20 }
    end

    it 'should preserve new lines in the original text' do
      nt1 = StringHelpers.linewrap_text(@s1, 20)
      l1 = nt1.split("\n")
      l1.each {|l| l.length.should <= 20 }

      nt2 = StringHelpers.linewrap_text(@s2, 20)
      l2 = nt2.split("\n")
      l2.length.should > l1.length+2
    end
  end
end
