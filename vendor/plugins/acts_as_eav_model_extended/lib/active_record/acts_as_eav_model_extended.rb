#
# Monkeypatch Acts::EavModeul
#
# Need to do this because we added that 'visible' column...
# NOTE: These methods assume that we're looking for the default attribute class
# (cf. eav_attribute_default_class)
#

module ActiveRecord # :nodoc:
  module Acts
    module EavModel
      module ClassMethods
        
        # FlexAttributes does the same thing at init time but it's not factored out...
        def eav_attribute_default_class
          # SSS: May 13, 2011; self.class_name is deprecated in Rails 2.3.  self.name is good enough so using that instead!
          "#{self.name}Attribute".constantize
        end
        
      end
      
      module InstanceMethods
        
        # used by profile display page; hide flex attributes which user set to not be 'visible'
        # first check if attr is in model's own table, then check separate attrs table.
        def visible_attribute(key)
          if attributes.has_key?(key)
            return send(key)
          elsif eav_options[self.class.eav_attribute_default_class.to_s][:fields].include?(key)
            record = find_raw_eav_attribute(key)
            return record.value if record && ((record.respond_to?(:visible) && record.visible) || !record.respond_to?(:visible))
          end
        end
        
        # for building edit profile form
        def raw_flex_attribute(key,visible=true)
          eav_attr = find_raw_eav_attribute(key)
          if eav_attr.nil?
            foreign_key = eav_options[self.class.eav_attribute_default_class.name][:foreign_key]
            eav_attr = self.class.eav_attribute_default_class.new(:name => key, :visible => visible, foreign_key => self.id)
          end
          return eav_attr
        end
        
        # for processing form input
        def flex_attributes_params=(eav_attributes_params)
          if eav_attributes_params && !eav_attributes_params.empty?
            eav_attributes_params.each do |key, attribute_params|
              eav_attr = find_raw_eav_attribute(key)
              if eav_attr.nil? && !attribute_params["value"].blank?
                send("#{key}=", attribute_params["value"]) # implicitly creates eav_attr
                eav_attr = find_raw_eav_attribute(key)
              end
              eav_attr.update_attributes(attribute_params) if eav_attr
            end
          end
        end
        
        
        protected
          # Retrieve the related flex attribute object
          def eav_related_attr(model, attr)
              name_field = eav_options[model.name][:name_field]
              eav_related(model).to_a.find {|r| r.send(name_field) == attr}
          end
          
          def find_raw_eav_attribute(key)
            eav_related_attr(self.class.eav_attribute_default_class, key)
          end
          
      end
    end
  end
end
