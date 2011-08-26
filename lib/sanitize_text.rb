include Sanitize
module SanitizeText
  def self.included(base)
    base.class_eval do
      base.columns.each do |column|
        if column.type == :string || column.type == :text
          define_method("sanitized_#{column.name}") do
            (read_attribute(column.name.to_sym)) ? sanitize_html(read_attribute(column.name.to_sym)) : nil 
          end
          define_method("stripped_#{column.name}") do
            (read_attribute(column.name.to_sym)) ? __send__(column.name).dup.gsub(html_regexp, '') : nil 
          end
          
          private
          def html_regexp
            %r{<(?:[^>"']+|"(?:\\.|[^\\"]+)*"|'(?:\\.|[^\\']+)*')*>}xm
          end
        end
      end
    end
  end
end