slugs = %w(bfa-green bfa-humanities12-block1 bfa-humanities12-block3 bfa-humanities12-block5 bfa-social-justice bfa-labor bfa-race bfa-tech)

slugs.each { |sl|
	g = Group.find_by_slug(sl)
	puts "--- group #{g.id}: #{g.slug}: #{g.name}, #{g.memberships.count} members --- "
	g.memberships.each { |ms|
	  m = ms.member
	  puts "  Member #{m.id}, #{m.name}\t\t # reviews: #{m.total_reviews}"
	}
}; ""

all_bfa_members = slugs.collect { |s| Group.find_by_slug(s).memberships.map(&:member) }.flatten.uniq; ""
puts "--- # students added to 1 or more of the #{slugs.count} groups: #{all_bfa_members.count} ---"
all_bfa_members.each { |m|
  puts "  Member #{m.id}, #{m.name}\t\t # reviews: #{m.total_reviews}"
}; ""

# select members.id,members.name,(select group_concat(memberships.membershipable_id) from memberships where memberships.member_id=members.id group by member_id) as memberships_count from members join member_attributes m1 on m1.member_id=members.id where m1.name="invitation_code" and m1.value like '%balt-freedom%' and members.status='member';
