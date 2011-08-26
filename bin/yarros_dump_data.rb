module Yarros
  def self.dump_review_data(fh, n=1000)
    bt_id = Tag.find_by_name("Baltimore").id
    demographic_fields = %w(age_group expertise languages gender income politics city state journalism_experience education_experience)
    rand_ids = (1..50000).to_a.shuffle
    review_ids = Review.find(:all, :select => "reviews.id", :joins => [:story, :member], :conditions => ["stories.status IN ('list','feature') AND members.status = 'member' AND reviews.status IN ('list', 'feature') AND reviews.created_at >= ? AND reviews.created_at <= ?", Time.parse("2010-01-01"), Time.parse("2011-03-01")], :limit => n)
    review_ids.each { |rstub|
      r = Review.find(rstub.id)
      m = r.member
      s = r.story
      s_tags = s.topic_or_subject_tags
      is_balt = Tagging.exists?(:taggable_id => s.id, :tag_id => bt_id)
      fh.puts(([r.id, m.id, rand_ids[m.id], r.created_at.strftime("%Y-%m-%d"), r.rating] + [s.url.gsub(/\|.*/, ""), is_balt, s.story_date.strftime("%Y-%m-%d"), s.rating, s_tags.map(&:name) * ','] + [m.created_at.strftime("%Y-%m-%d"), m.validation_level, m.rating] + demographic_fields.collect { |f| m.send(f) } + r.ratings.collect { |rt| "#{rt.criterion}=#{rt.value}" }) * "|")
    }
    ""
  end

  def self.dump_group_review_data(fh, g_id)
    grp = Group.find(g_id)
    m_ids = grp.members.map(&:id)
    bt_id = Tag.find_by_name("Baltimore").id
    demographic_fields = %w(age_group expertise languages gender income politics city state journalism_experience education_experience)
    review_ids = Review.find(:all, :select => "reviews.id", :joins => [:story, :member], :conditions => ["stories.status IN ('list','feature') AND members.status = 'member' AND reviews.status IN ('list', 'feature') AND reviews.member_id IN (?) AND reviews.created_at >= ? AND reviews.created_at <= ?", m_ids, Time.parse("2010-01-01"), Time.parse("2011-03-01")])
    review_ids.each { |rstub|
      r = Review.find(rstub.id)
      m = r.member
      s = r.story
      s_tags = s.topic_or_subject_tags
      is_balt = Tagging.exists?(:taggable_id => s.id, :tag_id => bt_id)
      fh.puts(([r.id, m.id, r.created_at.strftime("%Y-%m-%d"), r.rating] + [s.url.gsub(/\|.*/, ""), is_balt, s.story_date.strftime("%Y-%m-%d"), s.rating, s_tags.map(&:name) * ','] + [m.created_at.strftime("%Y-%m-%d"), m.validation_level, m.rating] + demographic_fields.collect { |f| m.send(f) } + r.ratings.collect { |rt| "#{rt.criterion}=#{rt.value}" }) * "|")
    }
    ""
  end

  def dump_it
    fh = File.open("/tmp/all.review.data", "w")
    fh.puts(["Review:Id", "Member:Id", "Member:Rand Id", "Review:Date", "Review:Rating", "Story:Url", "Story:Baltimore?", "Story:Date", "Story:Rating", "Story:Tags", "Member:Signup Date", "Member:Validation Level", "Member:Rating", "Member:Age Group", "Member:Expertise", "Member:Languages", "Member:Gender", "Member:Income", "Member:Politics", "Member:City", "Member:State", "Member:Journalism Experience", "Member:Education Experience"] * "|")
    dump_review_data(fh, 50000)
    fh.close

    fh = File.open("/tmp/group.review.data", "w")
    fh.puts(["Review:Id", "Member:Id", "Review:Date", "Review:Rating", "Story:Url", "Story:Baltimore?", "Story:Date", "Story:Rating", "Story:Tags", "Member:Signup Date", "Member:Validation Level", "Member:Rating", "Member:Age Group", "Member:Expertise", "Member:Languages", "Member:Gender", "Member:Income", "Member:Politics", "Member:City", "Member:State", "Member:Journalism Experience", "Member:Education Experience"] * "|")
    dump_group_review_data(fh, 38)
    fh.close
  end

  def self.read_member_map
    mmap = {}
    File.open("nt_member_map", "r").each_line { |l|
      orig, mapped = l.strip.split(",")
      mmap[orig.to_i] = mapped
    }
    mmap
  end

  def self.dump_rating_map
    fh = File.open("/tmp/rating.data", "w")
    mmap = read_member_map
    ratings = MetaReview.find(:all, :conditions => ["created_at >= ? and created_at <= ?", Time.parse("2010-01-01"), Time.parse("2011-03-01")])
    ratings.each { |r|
      m1 = r.member_id
      m2 = r.review.member_id
      if (mmap[m1] && mmap[m2])
        fh.puts [mmap[m1], r.rating, mmap[m2], r.review.story.url] * "|"
      else
        puts "none for #{m1} or #{m2}"
      end
    }
    fh.close
  end
end

Yarros.dump_rating_map
