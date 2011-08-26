module QueryHelpers
  def self.conditions_array(conds)
    cstr = conds.collect { |c| "(#{c.first})" }.join(" AND ")
    conds.inject([cstr]) { |cp, c| c.shift; cp + c.compact }
  end
end
