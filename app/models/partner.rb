class Partner < ActiveRecord::Base
  has_friendly_id :name, :use_slug => true
  has_many :memberships, :as => :membershipable
  has_many :private_members, :through => :memberships, :source => :member, :conditions => ['public = ?', false]
  has_many :members, :through => :memberships, :conditions => ['public = ?', true], :extend => MembershipAssociationExtension
  has_many :invitations
  validates_presence_of :name
  validates_uniqueness_of :name
  attr_protected :memberships, :invitations

    # If primary_invite_id is not set, get the first available invitation
  def primary_invite
    self.primary_invite_id ? Invitation.find(self.primary_invite_id) : self.invitations.find(:first)
  end

  def primary_invite=(invitation)
    self.primary_invite_id = invitation ? invitation.id : nil
    self.save!
  end

  def is_primary_invite(invitation)
    invitation.id == self.primary_invite_id
  end
end
