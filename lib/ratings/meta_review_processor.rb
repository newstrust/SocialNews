# just turn the one rating into a "overall"
#

module Ratings
  class MetaReviewProcessor < Processor
    # online_request: this is a request that originated from a web http request => minimal processing
    # if not, it is an offline request, and we can take all the time in the world
    def initialize(meta_review, online_request, group)
      @meta_review = meta_review
    end

    # Initialize meta rating value for the review so that a zero meta-rating doesn't show up for a review
    # till the complete meta-rating is processed
    def do_quick_approx_propagation
      review = @meta_review.review
      if MetaReview.count(:conditions => {:review_id => review.id}) == 1
        ProcessedRating.create(:processable_id => review.id, :processable_type => review.class.name, :rating_type => "meta", :value => @meta_review.rating)
      end
    end

    def process
      # Meta review rating is not dependent on group-specific ratings.
      {0 => {"overall" => @meta_review.component_rating("recommendation")}}
    end
  end
end
