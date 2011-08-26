require 'active_record/acts_as_eav_model_extended'
ActiveRecord::Base.send :include, ActiveRecord::Acts::EavModel
