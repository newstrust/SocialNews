include ActionView::Helpers::SanitizeHelper
class Subject < Topic
  define_index do
    indexes :name, :sortable => true
  end

  def self.site_subjects(local_site=nil, find_opts={})
    Subject.for_site(local_site).find(:all, find_opts)
  end

  def self.national_subjects
    site_subjects(nil)
  end

  def self.find_subject(slug, local_site=nil)
    Subject.for_site(local_site).find(:first, :conditions => {:slug => slug})
  end

  def self.tagged_subject(tag, local_site=nil)
    Subject.for_site(local_site).find(:first, :conditions => {:tag_id => tag.id})
  end

  def groupings
    Subject.groupings_for(slug).collect{|g| g.keys.first}
  end
  
  def grouping(group)
    Subject.grouping_for(slug, group)
  end
  
  # just in case subject gets treated as a topic...
  def subjects
    []
  end

  def is_high_volume?
    topic_volume <= SocialNewsConfig["high_volume_subject_days"]
  end

  def is_minor_subject?
    topic_volume >= 30
  end

  # for topics_column
  def topics_by_grouping(local_site=nil)
    topics_by_grouping = {}
    TopicRelation.find(:all, :conditions => {:local_site_id => local_site ? local_site.id : nil, :related_topic_id => self.id}).each do |topic_relation|
      grouping = topic_relation.grouping || :none
      topics_by_grouping[grouping] ||= []
      topics_by_grouping[grouping] << topic_relation.topic unless topic_relation.topic.id == self.id # weird condition
    end
    topics_by_grouping.each{|g, topic_list| topics_by_grouping[g] = topic_list.sort{|tx, ty| tx["name"] <=> ty["name"]}}
    return topics_by_grouping
  end

  # for 'all topics' page
  def topics(find_options={}, topic_status=["list", "feature"])
    find_options[:joins]      = " JOIN topic_relations on topics.id=topic_relations.topic_id" +
                                " JOIN tags ON tags.id = topics.tag_id" +
                                " #{find_options[:joins]}"
    find_options[:conditions] = "topic_relations.related_topic_id = #{self.id}" +
                                " AND topic_relations.context = 'subject'" +
                                " #{find_options[:conditions]}"
    Topic.topics_only.for_site(self.local_site).with_status(topic_status).find(:all, find_options)
  end

  # for 'featured topics' page
  def featured_topics(find_options={})
    topics(find_options, "feature")
  end

  def top_sources
    Source.top_sources_for_subject(self)
  end
  
  class << self
    def search(str, options = {})
      Topic.search(str, options.merge(:conditions => { :type => 'Subject' }))
    end
    
    def names
      TopicRelation.topic_subjects
    end
    
    def groupings_for(subject)
      TopicRelation.topic_subject_groupings(subject)["groupings"]
    end
    
    def groupings_for_select(subject)
      groupings_for(subject).collect{|g| [g.values.first["name"], g.keys.first]}
    end
    
    def grouping_for(name, group)
        grouping = groupings_for(name).select{|g| g.keys.first==group}
        raise "No grouping for #{group}" if grouping.empty?
        return grouping.first.values.first["name"]
      rescue RuntimeError
        nil      
    end
  end
end
