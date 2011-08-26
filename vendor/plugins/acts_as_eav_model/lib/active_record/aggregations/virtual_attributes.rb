module ActiveRecord
  module Aggregations # :nodoc:
    module VirtualAttributes
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        private
        
        def reader_method(name, class_name, mapping, allow_nil, constructor=:new)
          module_eval do
            define_method(name) do |*args|
              force_reload = args.first || false
              if (instance_variable_get("@#{name}").nil? || force_reload) && (!allow_nil || mapping.any? {|pair| !send(pair.first).nil? })
                attrs = mapping.collect {|pair| send(pair.first)}
                object = case constructor
                  when Symbol
                    class_name.constantize.send(constructor, *attrs)
                  when Proc, Method
                    constructor.call(*attrs)
                  else
                    raise ArgumentError, 'Constructor must be a symbol denoting the constructor method to call or a Proc to be invoked.'
                  end
                instance_variable_set("@#{name}", object)
              end
              instance_variable_get("@#{name}")
            end
          end
        end
        
        def writer_method(name, class_name, mapping, allow_nil, converter)
          define_method("#{name}=") do |part|
            if part.nil? && allow_nil
              mapping.each {|pair| send("#{pair.first}=", nil)}
              instance_variable_set("@#{name}", nil)
            else
              unless part.is_a?(class_name.constantize) || converter.nil?
                part = case converter
                  when Symbol
                    class_name.constantize.send(converter, part)
                  when Proc, Method
                    converter.call(part)
                  else
                    raise ArgumentError, 'Converter must be a symbol denoting the converter method to call or a Proc to be invoked.'
                  end
              end
              mapping.each {|pair| send("#{pair.first}=", part.send(pair.last))}
              instance_variable_set("@#{name}", part.freeze)
            end
          end
        end
      end
    end
  end
end