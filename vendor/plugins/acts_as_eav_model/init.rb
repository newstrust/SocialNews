$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'active_record/acts/eav_model'
require 'active_record/aggregations/virtual_attributes'
ActiveRecord::Base.class_eval {
  include ActiveRecord::Acts::EavModel
  include ActiveRecord::Aggregations::VirtualAttributes
}