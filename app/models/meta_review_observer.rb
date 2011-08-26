class MetaReviewObserver < ActiveRecord::Observer
  def after_create(meta_review)
    # DISABLED FOR NOW. can dig the code back out from svn logs
    # when someone rates one of your reviews
  end
end
