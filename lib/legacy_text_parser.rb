# This class is used to reformat the text in the legacy database into a format more acceptable for Textile conversion.
class LegacyTextParser
  
  @@nestled_tag = /[>a-zA-Z]<[>a-zA-Z]/
  def initialize
  end
  class << self
    def format_member_attribute_favorite_link 
      # Convert all the list of links into a proper unordered list.
      MemberAttribute.find(:all, :conditions => ["name = ?", "favorite_links"]).each do |record|
        if record.value !~ /<ul>/
          record.update_attribute(:value, linebreaks_to_list(record.value))
        end
      end
      true
    end
    
    # In some cases single linebreaks were used to specify a new paragraph. Textile expects doubleline breaks
    # so we add another linebreak here.
    def double_all_linebreaks(str)
      str.gsub(/\n/, "\n\n")
    end
    
    # When certain tags like anchors are pressed up against preceeding letters textile will strip the HTML but
    # not convert it into a link. Therefore we need to give links an extra space if they don't have one.
    def add_space_before_tags(str)
      str.gsub!(@@nestled_tag) { |x| x.split('<').join(' <') }
    end
    
    def linebreaks_to_list(str)
       "<ul>" << str.split("\r\n").collect{|x| "<li>#{x}</li>" }.join('') <<"</ul>"
    end
  end
end