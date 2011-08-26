class TopicRelation < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :topic
  belongs_to :related_topic, :class_name => "Topic"
  
  @@topic_constants = YAML::load(ERB.new(IO.read("#{RAILS_ROOT}/config/social_news_constants/topic_constants.yml")).result)
  cattr_reader :topic_constants
  
  def self.topic_subjects
    topic_constants['topic_subjects'].map{ |x| x.keys.first }.flatten
  end
  
  def self.topic_subject_groupings(subject)
    raise "No grouping for #{subject}" unless self.topic_subjects.include?(subject)
    topic_constants['topic_subjects'].map {|x| x if x.keys.first == subject }.compact.first.values.first
  end
end
