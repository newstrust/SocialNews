#
# Monkeypatch time!
#

class Hash
  def compact
    self.reject{ |key, val| val.nil? }
  end
end
