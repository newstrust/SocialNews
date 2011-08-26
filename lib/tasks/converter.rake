require 'sgml-parser'
require 'html_to_textile_parser'
require 'legacy_text_parser'
require 'ruby-debug'
namespace :socialnews do
  
  desc "Convert ALL To Textile"
  task(:to_textile => :environment)do
    Rake::Task["socialnews:format_html_for_conversion"].invoke
    @tables = %w(Excerpt MemberAttribute Review SourceAttribute Story StoryAttribute Tag)
    Rake::Task["socialnews:html_to_textile"].invoke
  end

  # Some of these fields are meant to be parsed into specific entities in textile yet their HTML
  # doesn't match what it should be converted into. For example the links field in members is 
  # meant to display a list of urls but the saved HTML is just a series of links.
  desc "Format HTML for Conversion"
  task(:format_html_for_conversion => :environment) do
    LegacyTextParser.format_member_attribute_favorite_link()
  end
  
  desc "Convert HTML to Textile"
  task( :html_to_textile => :environment ) do
    verbosity = to_boolean(ENV['v'] || false)
    
    @tables ||= ENV['tables']
    raise(ArgumentError, "No table specified try using tables='ModelOne ModelTwo'") unless @tables
    @tables = [@tables.split(' ')].flatten
    @tables.each do |table|
      table = table.classify.constantize
      fields = table.columns_hash.map { |k,v| k if table.columns_hash[k].type == :text }.compact!
      puts "Converting all #{table} records that use HTML in these fields '#{fields.join(', ')}' " if verbosity
      table.find(:all).each do |record|
        fields.each do |x|
          next if record[x].nil?
          parser = HTMLToTextileParser.new
          pre = record[x]
          parser.feed(record[x])
          record[x]= parser.to_textile
          
          if (pre != record[x]) && verbosity
            sleep(0.1) # breath
            puts "---------------8< CUT HERE --------------------------------------"
            puts "\n\n"
            puts "change made to #{table} id=#{record.id}"
            puts "#{x} pre:\n" << pre
            puts "\n"
            puts "#{x} post:\n" << record[x]
            puts "\n\n"
          end
        end
        record.save
      end
    end
  end
  
  private
  def to_boolean(value)
    s = value
    s == "true" or s == "1"
  end
end
