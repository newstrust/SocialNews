# just turn the one rating into a "overall"
#

module Ratings
  class SourceReviewProcessor < Processor
    # online_request: this is a request that originated from a web http request => minimal processing
    # if not, it is an offline request, and we can take all the time in the world
    def initialize(source_review, online_request, group)
      @source_review = source_review
    end

    def do_quick_approx_propagation
      if !@source_review.rating.nil?
        src = @source_review.source
        ls  = @source_review.local_site
        stats = ls ? src.source_stats.find_by_local_site_id(ls.id) : src
        n = stats.source_reviews_count
        # rating is approximate since it is not weighted
        stats.update_attributes(:source_reviews_count => n+1, :review_rating => ((stats.review_rating * n) + @source_review.rating) / (n + 1.0))
      end
    end

    def process
      if !@source_review.rating.nil?
        # I am bypassing the acts_as_processable plugin here -- that thing is inflexible.
        src = @source_review.source
        ls  = @source_review.local_site
        if ls.nil?
          if !ProcessJob.exists?(:processable_id => src.id, :processable_type => src.class.name, :processor_method => "update_review_stats")
            ProcessJob.create(:processable => src, :processor_method => "update_review_stats")
          end
        else
          src_stat = src.source_stats.find_by_local_site_id(ls.id)
          if !ProcessJob.exists?(:processable_id => src_stat.id, :processable_type => src_stat.class.name, :processor_method => "update_review_stats")
            ProcessJob.create(:processable => src_stat, :processor_method => "update_review_stats")
          end
        end
      end

      # Source review rating is not dependent on group-specific ratings
      {0 => {"overall" => @source_review.component_rating("trust")} }
    end
  end
end
