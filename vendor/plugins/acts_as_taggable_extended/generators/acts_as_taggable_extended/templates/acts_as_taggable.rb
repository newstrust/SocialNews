module ActiveRecord
  module Acts #:nodoc:
    module Taggable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)  
      end
      
      module ClassMethods
        def acts_as_taggable(options = {})
          write_inheritable_attribute(:acts_as_taggable_options, {
            :taggable_type => ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s,
            :from => options[:from]
          })
          
          class_inheritable_reader :acts_as_taggable_options

          has_many :taggings, :as => :taggable, :dependent => :destroy
          has_many :tags, :through => :taggings, :conditions => ["taggings.context IS NULL OR taggings.context = 'tag'"] do
            def delete(records, <%= file_name.singularize %>_id)
              <%= file_name.singularize %>_id = <%= file_name.singularize %>_id.id unless <%= file_name.singularize %>_id.class == Fixnum || <%= file_name.singularize %>_id.nil?
              [records].flatten.each do |record|
                
                # Only query for this record if it supports an acts_as_taggable
                next unless record.methods.include?('taggings=')
                taggings = @owner.taggings.find(:all, :conditions => ["tag_id = ?", record.id])
                # taggings = Tagging.find(:all, :conditions => ["tag_id = ? AND taggable_id = ? AND Taggable_type = ?", record.id, @owner.id, @owner.class.to_s])

                # Delete only the tagging if multiple taggings exist for this taggable_id and tag combination.
                if taggings.size == 1 && taggings.first.<%= file_name.singularize %>_id == <%= file_name.singularize %>_id
                  record.destroy
                else
                  # Multiple <%= file_name.singularize %>s have tagged this item so just delete the tagging record.
                  taggings.each do |t|
                    t.tag.taggings.destroy(t.id) if t.<%= file_name.singularize %>_id == <%= file_name.singularize %>_id
                  end
                end unless taggings.empty?
              end
            end
          end

          include ActiveRecord::Acts::Taggable::InstanceMethods
          extend ActiveRecord::Acts::Taggable::SingletonMethods          
        end
      end
      
      module SingletonMethods
        # This method now selects distinct records because now that many classes can tag the same item with the same tag
        # duplicate records are returned.
        def find_tagged_with(list, options={})
          sql = "SELECT DISTINCT #{table_name}.* FROM #{table_name}, tags, taggings "
          sql += "WHERE #{table_name}.#{primary_key} = taggings.taggable_id "
          sql += "AND taggings.taggable_type = ? " 
          sql += "AND taggings.tag_id = tags.id AND tags.name IN (?) " 
          sql += "ORDER BY   " + options[:order] + " " if options[:order]
          sql += "LIMIT  " + options[:limit].to_s + " " if options[:limit]
          sql += "OFFSET " + options[:offset].to_s if options[:limit] && options[:offset]

          find_by_sql([sql,acts_as_taggable_options[:taggable_type], list])
        end
      end
      
      module InstanceMethods
        def tag_with(list, params = {})
          opts = { :<%= file_name.singularize %>_id => nil, :context => nil}.merge(params)
          opts[:<%= file_name.singularize %>_id] = opts[:<%= file_name.singularize %>_id].id unless opts[:<%= file_name.singularize %>_id].class == Fixnum || opts[:<%= file_name.singularize %>_id].nil?
          Tag.transaction do

            # The destroy_all in DHH's version of tag_with doesn't actually work without reloading the
            # records (taggings(true).destroy_all); it also takes as many SQL calls as there are tags. Lame.
            # This tag_with fixes all that.
            Tagging.destroy_all(["taggable_id = ? AND taggable_type = ? AND <%= file_name.singularize %>_id = ?", id, self.class.name, opts[:<%= file_name.singularize %>_id]]) if id

            # Replace any single quotes with double quotes
            # This will cause a potential problem on tags that include apostrophes like "tagg'n" which will appear "tagg"n"
            list = list.gsub(/'/, '"')
            @parsed_tags = Array.new

            Tag.parse(list).each do |name|
              tag = Tag.find_or_create_by_name(name)

              raise unless tag
              tag.name.include?(" ") ? @parsed_tags <<  "\"#{tag.name}\"" : @parsed_tags <<  tag.name

              if acts_as_taggable_options[:from]
                send(acts_as_taggable_options[:from]).taggings.create(:tag_id => tag.id, :<%= file_name.singularize %>_id => opts[:<%= file_name.singularize %>_id]).on(self)
              else
                self.taggings.create(:tag_id => tag.id, :<%= file_name.singularize %>_id => opts[:<%= file_name.singularize %>_id], :context => opts[:context])
              end
            end
          end

          tag_list = tags(true).map{ |x| (x.name.include?(" ")) ? "\"#{x.name}\"" : x.name }.uniq.join(', ')

          update_attribute(:tag_aggregate, tag_list) if self.attributes.include?('tag_aggregate')
          self.tags
        end

        def untag_with(str, params = {})
          opts = { :<%= file_name.singularize %>_id => nil, :context => nil }.merge(params)
          t = tags.find(:all, :conditions =>["name in (?)",str.split(',').each { |x| x.strip! }])
          tags.delete(t, opts[:<%= file_name.singularize %>_id])
        end

        # For our "Tag Aggregate" approach to fulltext indexing tags along with other attributes like title.
        # Every time the tags are changed, acts_as_taggable and our extension handle updating the Tag and Tagging models.
        # However, we still need to record the tag list in our tag_aggregate field, so it can be fulltext indexed by
        # MySQL.  This makes writes more expensive, but speeds up reads considerably.
        def tag_list=(opts)
          if @new_record
            @tag_list_from_params = opts[:tags]
            @<%= file_name.singularize %>_id = opts[:<%= file_name.singularize %>_id]
          else
            self.tag_list_writer = opts
          end
        end

        def tag_list_writer=(opts)

          # Remove duplicates and white spaces between words
          arr = opts[:tags].split(",").each { |x| x.strip! }.uniq
          tag_with(arr.map { |a| a }.join(","), opts.except(:tags))
        end

        def tag_list
          if @new_record
            @tag_list_from_params
            @<%= file_name.singularize %>_id
          else
            tags.collect { |tag| tag.name.include?(" ") ? "\"#{tag.name}\"" : tag.name }.join(", ")
          end
        end

        def after_create
          super
          self.tag_list_writer = {:tags => @tag_list_from_params, :<%= file_name.singularize %>_id => @<%= file_name.singularize %>_id } if @tag_list_from_params && @<%= file_name.singularize %>_id
        end
      end
    end
  end
end
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)