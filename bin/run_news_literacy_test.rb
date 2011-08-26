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
        all_prh = ProcessedRatingVersion.find(:all, :conditions => ["processable_id = ? and processable_type = ? and rating_type = ? and value < ? and value > ?", r.id, 'Review', "overall", r.rating + 0.001, r.rating - 0.001])
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

run_test("cs", 5111602); ""
run_test("csh", 5740142); ""
