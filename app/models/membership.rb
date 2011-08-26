class Membership < ActiveRecord::Base
  belongs_to :membershipable, :polymorphic => true, :counter_cache => 'memberships_count'
  belongs_to :member
  belongs_to :group,   :class_name => "Group", :foreign_key => "membershipable_id"
  belongs_to :partner, :class_name => "Partner", :foreign_key => "membershipable_id"
  has_one :invitation
  validates_uniqueness_of :member_id, :scope => [:membershipable_type, :membershipable_id]
  validates_presence_of :member_id
end
