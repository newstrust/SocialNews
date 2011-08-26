module ActiveRecord
  module Acts #:nodoc:
    module Tagger #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)  
      end
      
      module ClassMethods
        def acts_as_tagger(options = {})
          write_inheritable_attribute(:acts_as_tagger_options, {
            :taggable_type => ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s,
            :from => options[:from]
          })
          
          class_inheritable_reader :acts_as_tagger_options
          
          has_many :taggings
          has_many :my_tags, :through => :taggings, :uniq => true, :source => :tag, :order => :name
          
          include ActiveRecord::Acts::Tagger::InstanceMethods
        end
      end
      
      module InstanceMethods
        def my_tags_for(record)
          taggings = Tagging.find(:all, :conditions => ['<%= file_name.singularize %>_id = ? AND taggable_type = ? AND taggable_id = ?',id, record.class.to_s, record.id], :include => :tag)
          taggings.collect{ |t| t.tag }
        end
      end
      
    end
  end
end
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Tagger)