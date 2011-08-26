class Hosting < ActiveRecord::Base
  belongs_to :page_host, :class_name => "PageHost", :foreign_key => "page_host_id"
  belongs_to :hostable, :polymorphic => :true
  belongs_to :topic, :foreign_key => "hostable_id", :class_name => "Topic"
  belongs_to :source, :foreign_key => "hostable_id", :class_name => "Source"
end
