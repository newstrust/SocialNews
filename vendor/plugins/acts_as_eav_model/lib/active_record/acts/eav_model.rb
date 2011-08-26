module ActiveRecord # :nodoc:
  module Acts # :nodoc:
    module EavModel # :nodoc:
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        ##
        # Will make the current class have eav behaviour.
        #
        #   class Post < ActiveRecord::Base
        #     has_eav_behavior
        #   end
        #   post = Post.find_by_title 'hello world'
        #   puts "My post intro is: #{post.intro}"
        #   post.teaser = 'An awesome introduction to the blog'
        #   post.save
        #
        # The above example should work even though "intro" and "teaser" are not
        # attributes on the Post model.
        #
        # The following options are available on for has_eav_behavior to modify
        # the behavior. Reasonable defaults are provided:
        #
        # * <tt>class_name</tt>:
        #   The class for the related model. This defaults to the
        #   model name prepended to "Attribute". So for a "User" model the class
        #   name would be "UserAttribute". The class can actually exist (in that
        #   case the model file will be loaded through Rails dependency system) or
        #   if it does not exist a basic model will be dynamically defined for you.
        #   This allows you to implement custom methods on the related class by
        #   simply defining the class manually.
        # * <tt>table_name</tt>:
        #   The table for the related model. This defaults to the
        #   attribute model's table name.
        # * <tt>relationship_name</tt>:
        #   This is the name of the actual has_many
        #   relationship. Most of the type this relationship will only be used
        #   indirectly but it is there if the user wants more raw access. This
        #   defaults to the class name underscored then pluralized finally turned
        #   into a symbol.
        # * <tt>foreign_key</tt>:
        #   The key in the attribute table to relate back to the
        #   model. This defaults to the model name underscored prepended to "_id"
        # * <tt>name_field</tt>:
        #   The field which stores the name of the attribute in the related object
        # * <tt>value_field</tt>:
        #   The field that stores the value in the related object
        # * <tt>meta_columns</tt>:
        #   Additional columns on the related model. Allows you to define metadata
        #   on individual attributes. Examples:
        #  class User < ActiveRecord::Base
        #    has_eav_behavior :meta_columns=>{:private=>{:type=>:boolean, :default=>false}}
        #  end
        #
        #  user = User.first
        #  user.email = 'user@example.com'
        #  user.email_private # => false
        #  user.email_private = true
        #  user.save # will save a UserAttribute record with :name=>'email', :value=>'user@example.com', :private=>true
        #
        #  class User < ActiveRecord::Base
        #    has_eav_behavior :meta_columns=>{:unit=>:virtual}
        #  end
        #
        #  class UserAttribute < ActiveRecord::Base
        #    has_one :unit
        #  end
        #
        #  user = User.first
        #  user.height = 5
        #  user.height_unit = Unit.find_by_name('feet')
        # * <tt>fields</tt>:
        #   A list of fields that are valid eav attributes. By default
        #   this is "nil" which means that all field are valid. Use this option if
        #   you want some fields to go to one flex attribute model while other
        #   fields will go to another. As an alternative you can override the
        #   #eav_attributes method which will return a list of all valid flex
        #   attributes. This is useful if you want to read the list of attributes
        #   from another source to keep your code DRY. This method is given a
        #   single argument which is the class for the related model. The following
        #   provide an example:
        #
        #  class User < ActiveRecord::Base
        #    has_eav_behavior :class_name => 'UserContactInfo'
        #    has_eav_behavior :class_name => 'Preferences'
        #
        #    def eav_attributes(model)
        #      case model
        #        when UserContactInfo
        #          %w(email phone aim yahoo msn)
        #        when Preference
        #          %w(project_search project_order user_search user_order)
        #        else Array.new
        #      end
        #    end
        #  end
        #
        #  marcus = User.find_by_login 'marcus'
        #  marcus.email = 'marcus@example.com' # Will save to UserContactInfo model
        #  marcus.project_order = 'name'     # Will save to Preference
        #  marcus.save # Carries out save so now values are in database
        #
        # Note the else clause in our case statement. Since an empty array is
        # returned for all other models (perhaps added later) then we can be
        # certain that only the above eav attributes are allowed.
        #
        # If both a :fields option and #eav_attributes method is defined the
        # <tt>fields</tt> option take precidence. This allows you to easily define the
        # field list inline for one model while implementing #eav_attributes
        # for another model and not having #eav_attributes need to determine
        # what model it is answering for. In both cases the list of flex
        # attributes can be a list of string or symbols
        #
        # A final alternative to :fields and #eav_attributes is the
        # #is_eav_attribute? method. This method is given two arguments. The
        # first is the attribute being retrieved/saved the second is the Model we
        # are testing for. If you override this method then the #eav_attributes
        # method or the :fields option will have no affect. Use of this method
        # is ideal when you want to retrict the attributes but do so in a
        # algorithmic way. The following is an example:
        #   class User < ActiveRecord::Base
        #     has_eav_behavior :class_name => 'UserContactInfo'
        #     has_eav_behavior :class_name => 'Preferences'
        #
        #     def is_eav_attribute?(attr, model)
        #       case attr.to_s
        #         when /^contact_/ then true
        #         when /^preference_/ then true
        #         else
        #           false
        #       end
        #     end
        #   end
        #
        #   marcus = User.find_by_login 'marcus'
        #   marcus.contact_phone = '021 654 9876'
        #   marcus.contact_email = 'marcus@example.com'
        #   marcus.preference_project_order = 'name'
        #   marcus.some_attribute = 'blah'  # If some_attribute is not defined on
        #                                   # the model then method not found is thrown
        #
        def has_eav_behavior(options = {})
          # SSS: May 13, 2011; self.class_name is deprecated in Rails 2.3.  self.name is good enough so using that instead!
          class_name = self.name

          options[:class_name] ||= class_name + 'Attribute'
          options[:table_name] ||= options[:class_name].tableize
          options[:relationship_name] ||= options[:class_name].tableize.to_sym
          options[:foreign_key] ||= class_name.foreign_key
          options[:base_foreign_key] ||= self.name.underscore.foreign_key
          options[:name_field] ||= 'name'
          options[:value_field] ||= 'value'
          options[:fields].collect! {|f| f.to_s} unless options[:fields].nil?
          options[:parent] = class_name
          options[:meta_columns] ||= {}

          # Init option storage if necessary
          cattr_accessor :eav_options
          self.eav_options ||= Hash.new

          # Return if already processed.
          return if self.eav_options.keys.include? options[:class_name]

          # Attempt to load related class. If not create it
          begin
            options[:class_name].constantize
          rescue
            Object.const_set(options[:class_name],
            Class.new(ActiveRecord::Base)).class_eval do
              def self.reloadable? #:nodoc:
                false
              end
            end
          end

          # Store options
          self.eav_options[options[:class_name]] = options

          # Only mix instance methods once
          unless self.included_modules.include?(ActiveRecord::Acts::EavModel::InstanceMethods)
            send :include, ActiveRecord::Acts::EavModel::InstanceMethods
          end

          # Modify attribute class
          attribute_class = options[:class_name].constantize
          base_class = self.name.underscore.to_sym

          attribute_class.class_eval do
            belongs_to base_class, :foreign_key => options[:base_foreign_key]
            alias_method :base, base_class # For generic access
          end

          # Modify main class
          class_eval do
            has_many options[:relationship_name],
              :class_name => options[:class_name],
              :table_name => options[:table_name],
              :foreign_key => options[:foreign_key],
              :dependent => :destroy

            # The following is only setup once
            unless method_defined? :method_missing_without_eav_behavior

              # Carry out delayed actions before save
              after_validation_on_update :save_modified_eav_attributes

              # Make attributes seem real
              alias_method_chain :method_missing, :eav_behavior
              alias_method_chain :respond_to?, :eav_behavior

              private

              alias_method_chain :execute_callstack_for_multiparameter_attributes, :eav_behavior
              alias_method_chain :read_attribute, :eav_behavior
              alias_method_chain :write_attribute, :eav_behavior

            end
          end
          
          create_attribute_table
          
        end
        alias_method :has_attributes, :has_eav_behavior

      end

      module InstanceMethods

        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end
        
        module ClassMethods

          ##
          # Rake migration task to create the versioned table using options passed to has_eav_behavior
          #
          def create_attribute_table(options = {})
            # SSS: May 13, 2011; self.class_name is deprecated in Rails 2.3.  self.name is good enough so using that instead!
            eav_options.keys.each do |key|
              continue if eav_options[key][:parent] != self.name
              model = eav_options[key][:class_name]

              return if connection.tables.include?(eav_options[model][:table_name])

              self.connection.create_table(eav_options[model][:table_name], options) do |t|
                t.integer eav_options[model][:foreign_key], :null => false
                t.string eav_options[model][:name_field], :null => false
                t.string eav_options[model][:value_field], :null => false
                eav_options[model][:meta_columns].each do |name, column_options|
                  next if column_options == :virtual
                  t.column name, column_options[:type], column_options.slice(:limit, :default, :null, :precision, :scale)
                end

                t.timestamps
              end

              self.connection.add_index eav_options[model][:table_name], eav_options[model][:foreign_key]
            end

          end

          ##
          # Rake migration task to drop the attribute table
          #
          def drop_attribute_table(options = {})
            # SSS: May 13, 2011; self.class_name is deprecated in Rails 2.3.  self.name is good enough so using that instead!
            eav_options.keys.each do |key|
              continue if eav_options[key][:parent] != self.name
              model = eav_options[key][:class_name]
              self.connection.drop_table eav_options[model][:table_name]
            end
          end
        end
        
        def execute_callstack_for_multiparameter_attributes_with_eav_behavior(callstack)
          eav_callstack = {}
          regular_callstack = callstack.dup
          callstack.each do |name, values|
            exec_if_related(name) {|model| eav_callstack[name] = values; regular_callstack.delete(name) }
          end
          execute_callstack_for_multiparameter_attributes_without_eav_behavior(regular_callstack)
          errors = []
          eav_callstack.each do |name, values|
            exec_if_related(name) do |model|
              meta_name = meta_attribute_name(name, model)
              if values.empty?
                send("#{name}=", nil)
              else
                klass = (model.reflect_on_aggregation(meta_name.to_sym)).klass
                begin
                  send("#{name}=", klass.new(*values))
                rescue => ex
                  errors << AttributeAssignmentError.new("error on assignment #{values.inspect} to #{name}", ex, name)
                end
              end
            end
          end
          unless errors.empty?
            raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes"
          end
        end

        ##
        # Will determine if the given attribute is a eav attribute on the
        # given model. Override this in your class to provide custom logic if
        # the #eav_attributes method or the :fields option are not flexible
        # enough. If you override this method :fields and #eav_attributes will
        # not apply at all unless you implement them yourself.
        #
        def is_eav_attribute?(attribute_name, model)
          attribute_name = attribute_name.to_s
          model_options = eav_options[model.name]
          return model_options[:fields].include?(attribute_name) unless model_options[:fields].nil?
          return eav_attributes(model).collect {|field| field.to_s}.include?(attribute_name) unless
            eav_attributes(model).nil?
          true
        end
        
        ##
        # Return a list of valid eav attributes for the given model. Return
        # nil if any field is allowed. If you want to say no field is allowed
        # then return an empty array. If you just have a static list the :fields
        # option is most likely easier.
        #
        def eav_attributes(model); nil end

        private
        
        def is_meta_attribute?(attribute_name, model)
          meta_name = meta_attribute_name(attribute_name, model)
          meta_name && is_eav_attribute?(attribute_name.to_s.sub(/_#{meta_name}$/, ''), model)
        end
        
        def meta_attribute_name(attribute_name, model)
          model_options = eav_options[model.name]
          meta_names = model_options[:meta_columns].keys
          return nil if meta_names.empty?
          return meta_names.detect {|meta_name| attribute_name =~ /_#{meta_name}$/ }
        end
        
        def base_attribute_name(attribute_name, model)
          attribute_name.to_s.sub(/_#{meta_attribute_name(attribute_name, model)}$/, '')
        end

        ##
        # Called after validation on update so that eav attributes behave
        # like normal attributes in the fact that the database is not touched
        # until save is called.
        #
        def save_modified_eav_attributes
          return if @save_eav_attr.nil?
          @save_eav_attr.each do |s|
            model, attribute_name = s
            related_attribute = find_related_eav_attribute(model, attribute_name)
            unless related_attribute.nil?
              if related_attribute.send(eav_options[model.name][:value_field]).nil?
                eav_related(model).delete(related_attribute)
              else
                related_attribute.save
              end
            end
          end
          @save_eav_attr = []
        end

        ##
        # Overrides ActiveRecord::Base#read_attribute
        #
        def read_attribute_with_eav_behavior(attribute_name)
          attribute_name = attribute_name.to_s
          exec_if_related(attribute_name) do |model|
            model_options = eav_options[model.name]
            value_field = meta_attribute_name(attribute_name, model) || model_options[:value_field]
            related_attribute = find_related_eav_attribute(model, attribute_name)
            
            if related_attribute.nil?
              return model_options[:meta_columns][value_field][:default] if is_meta_attribute?(attribute_name, model) && model_options[:meta_columns][value_field].is_a?(Hash)
              return nil
            end
            return related_attribute.send(value_field)
          end
          read_attribute_without_eav_behavior(attribute_name)
        end

        ##
        # Overrides ActiveRecord::Base#write_attribute
        #
        def write_attribute_with_eav_behavior(attribute_name, value)
          attribute_name = attribute_name.to_s
          exec_if_related(attribute_name) do |model|
            value_field = meta_attribute_name(attribute_name, model) || eav_options[model.name][:value_field]
            @save_eav_attr ||= []
            @save_eav_attr << [model, attribute_name]
            related_attribute = find_related_eav_attribute(model, attribute_name)
            if related_attribute.nil?
              unless value.nil?
                name_field = eav_options[model.name][:name_field]
                foreign_key = eav_options[model.name][:foreign_key]
                eav_related(model).build(name_field => base_attribute_name(attribute_name, model), foreign_key => self.id).send("#{value_field}=", value)
              end
              return value
            else
              value_field = (value_field.to_s + '=').to_sym
              return related_attribute.send(value_field, value)
            end
          end
          write_attribute_without_eav_behavior(attribute_name, value)
        end

        ##
        # Implements eav-attributes as if real getter/setter methods
        # were defined.
        #
        def method_missing_with_eav_behavior(method_id, *args, &block)
          begin
            method_missing_without_eav_behavior(method_id, *args, &block)
          rescue NoMethodError => e
            attribute_name = method_id.to_s.sub(/\=$/, '')
            exec_if_related(attribute_name) do |model|
              if method_id.to_s =~ /\=$/
                return write_attribute_with_eav_behavior(attribute_name, args[0])
              else
                return read_attribute_with_eav_behavior(attribute_name)
              end
            end
            raise e
          end
        end
        
        def respond_to_with_eav_behavior? method, include_private=false
          return true if respond_to_without_eav_behavior?(method, include_private) 
          exec_if_related(method.to_s.sub(/\=$/, '')) {|model| return true} if method.to_s !~ /^(created|updated)_(on|at)$/
          return false
        end

        ##
        # Retrieve the related eav attribute object
        #
        def find_related_eav_attribute(model, attribute_name)
          name_field = eav_options[model.name][:name_field]
          base_name = base_attribute_name(attribute_name, model)
          eav_related(model).to_a.find do |relation| 
            relation.send(name_field) == base_name
          end
        end

        ##
        # Retrieve the collection of related eav attributes
        #
        def eav_related(model)
          relationship = eav_options[model.name][:relationship_name]
          send relationship
        end

        ##
        # yield only if attribute_name is a eav_attribute
        #
        def exec_if_related(attribute_name)
          return false if self.class.column_names.include?(attribute_name)
          each_eav_relation do |model|
            if is_eav_attribute?(attribute_name, model) || is_meta_attribute?(attribute_name, model)
              yield model
            end
          end
        end

        ##
        # yields for each eav relation.
        #
        def each_eav_relation
          eav_options.keys.each {|kls| yield kls.constantize}
        end

      end

    end
  end
end
