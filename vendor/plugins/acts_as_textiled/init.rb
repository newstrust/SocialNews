begin
  require 'RedCloth'
rescue LoadError
  nil
end

require 'acts_as_textiled'
# SSS: May 13, 2011 -- from https://github.com/defunkt/acts_as_textiled/pull/1
require 'instance_tag_monkey_patch'
ActiveRecord::Base.send(:include, Err::Acts::Textiled)
