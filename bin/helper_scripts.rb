# ----------- add survey codes ----------
def add_survey_codes
  f = File.open("baltimore.survey_codes.csv", "r")
  f.each_line { |l|
    next if l.strip.empty?
    a = l.gsub(/".*?"/, "dummy").split(",").map(&:strip)
    m_id = a[7].gsub(%r|.*/|, '').to_i
    m = Member.find_by_id(m_id)
    if m.nil? || (m.name.downcase != a[0].downcase)
  	 puts "Invalid entry: m_name: #{m ? m.name : '--NONE--'}; name: #{a[0]}: id: #{m_id}, invite code: #{a[8]}, survey code: #{a[9]}"
    else
  	 m.bypass_save_callbacks = true
  	 m.update_attribute(:survey_code, a[9])
    end
  }
end

# ----------- run news literacy test ----------
def f_round(v, n)
  (v * 10**n).round.to_f/10**n
end

def run_test(survey_code, s_id)
  eds = Group.find(16)
  start_date = Time.parse("2011-01-31").beginning_of_day
  end_date = Time.parse("2011-04-30").end_of_day
  m_cs = Member.find(:all, :joins => ["member_attributes"], :conditions => {"member_attributes.name" => "survey_code", "member_attributes.value" => survey_code})
  s_cs = Story.find(s_id)
  reviews = s_cs.reviews
  baseline_rating = s_cs.group_rating(eds)
  m_cs.each { |m|
    r = reviews.find(:first, :conditions => ["member_id = ? AND created_at <= ? AND created_at >= ?", m.id, end_date, start_date])
    if r.nil?
       puts "#{m.name},,"
    else
      prh = ProcessedRatingVersion.find(:first, :conditions => {:processable_id => r.id, :processable_type => 'Review', :rating_type => "overall"})
      revision_str = nil
      if prh && (prh.value - r.rating >= 0.01)
        all_prh = ProcessedRatingVersion.find(:all, :conditions => {:processable_id => r.id, :processable_type => 'Review', :rating_type => "overall"})
        prh_2 = all_prh[1]
        revision_time = prh_2 ? prh_2.created_at : r.updated_at
        revision_str = "#{prh.value}; curr: #{r.rating}; approx orig rating time: #{prh.created_at}; approx revision time: #{revision_time}"
      end
      rating = prh ? prh.value : r.rating
      variance = r.rating - baseline_rating
      puts "#{m.name},#{f_round(rating,2)},#{f_round(variance,2)}"
      puts " --> Revisions: #{revision_str}" if revision_str
    end
  }
end

## run_test("cs", 5111602); ""
## run_test("csh", 5740142); ""

# ----------- add featured review block to all topics ----------
def add_fr_block_to_site(ls = nil)
  eb = EditorialBlock.find_by_slug("featured_review")
  Topic.for_site(ls).find(:all).each { |t|
    begin
      es_attrs = { :local_site_id => ls ? ls.id : nil, :page_type => t.class.name, :page_id => t.id }
      es = EditorialSpace.find(:first,
                               :joins => "join editorial_block_assignments eba ON eba.editorial_space_id=editorial_spaces.id",
                               :conditions => es_attrs.merge("eba.editorial_block_id" => eb.id))
      if es
        puts "Topic #{t.id}:#{t.name} has featured review block already: ES: #{es.id}"
      else
        es = EditorialSpace.create(es_attrs.merge(:name => "Featured Reviewer", :show_name => 1, :context => "right_column", :position => 1))
        eba = EditorialBlockAssignment.create(:editorial_space_id => es.id, :editorial_block_id => eb.id)
        puts "Added ES: #{es.id}; EBA: #{eba.id} for topic #{t.id}:#{t.name}"
      end
    rescue Exception => e
      puts "Exception #{e} for topic #{t.id}:#{t.name}; BT: #{e.backtrace.inspect}"
    end
  }
end

## add_fr_block_to_site; ""
