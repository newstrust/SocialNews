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
