class Tag < ActiveRecord::Base
  has_many :taggings, :dependent => :destroy

  # Tag names are unique!
  validates_uniqueness_of :name, :message => 'There already exists another tag with this name!'
  acts_as_textiled :discussion_description
  has_many :comments, :as => :commentable, :dependent => :destroy
  named_scope :commentable, :conditions => { :allow_comments => true }

  TOPIC   = "Topic"
  SUBJECT = "Subject"
  
  def self.parse(list)
    # Create a copy of the list object so that we modify don't modify the original object
    list = list.dup if list
    tag_names = []

    # first, pull out the quoted tags
    list.gsub!(/\"(.*?)\"\s*/ ) { tag_names << $1; "" }

    # then, replace all commas with a space
    list.gsub!(/,/, " ")

    # then, get whatever's left
    tag_names.concat list.split(/\s/)

    # strip whitespace from the names
    tag_names = tag_names.map { |t| t.strip }

    # delete any blank tag names
    tag_names = tag_names.delete_if { |t| t.empty? }
    
    return tag_names
  end
  
  def self.find_popular(args = {})
    find(:all, :select => 'tags.*, count(*) as popularity', 
      :limit => args[:limit] || 10,
      :joins => "JOIN taggings ON taggings.tag_id = tags.id",
      :conditions => args[:conditions],
      :group => "taggings.tag_id", 
      :order => "popularity DESC"  )
  end

  def self.curate(t)
      ## Obama, Barack --> Barack Obama; but, leave it as is if there are multiple words or non-text characters after the comma
    t = $2+' '+$1 if (t =~ /(.*?),\s*(\w[\w\d]*)/)
    return t
  end

  def self.quote(t)
    t = "\"#{t}\"" if (t =~ /\s/)
    return t
  end

  def tagged
    @tagged ||= taggings.collect { |tagging| tagging.taggable }
  end
  
  def on(taggable)
    taggings.create :taggable => taggable
  end
  
  def ==(comparison_object)
    super || name == comparison_object.to_s
  end
  
  def to_s
    name
  end

  def is_topic_tag?
    tag_type == TOPIC
  end

  def is_subject_tag?
    tag_type == SUBJECT
  end

  def is_topic_or_subject_tag?
    [SUBJECT, TOPIC].include?(tag_type)
  end
end
