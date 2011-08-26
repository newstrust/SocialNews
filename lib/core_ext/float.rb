#
# Monkeypatch time!
#

class Float
  # hard to believe that this functionality isn't built into Ruby... is it?!?!
  def constrain(range)
    if self > range.end
      return range.end
    elsif self < range.begin
      return range.begin
    else
      return self
    end
  end
end
