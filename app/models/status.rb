module Status
  LIST    = "list"
  FEATURE = "feature"
  HIDE    = "hide"
  PENDING = "pending"
  LOCKED  = "locked"
  DUPE    = "duplicate"

  VISIBLE = [LIST, FEATURE, LOCKED]
  ALL     = VISIBLE + [PENDING, HIDE]

  def hidden?
    status == HIDE
  end

  def featured?
    status == FEATURE
  end

  def locked?
    status == LOCKED
  end

  def dupe?
    status == DUPE
  end
end
