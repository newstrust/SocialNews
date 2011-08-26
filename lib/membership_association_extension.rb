module MembershipAssociationExtension
  def <<(record)
    return false if @owner.members(true).include? record
    @owner.memberships.create(:member_id => record.id)
  end
      
  def delete(record)
    record.destroy if record.class == Membership
    if record.class == Member
      membership = @owner.memberships.find_by_member_id(record.id)
      membership.destroy if membership
    end
  end
end