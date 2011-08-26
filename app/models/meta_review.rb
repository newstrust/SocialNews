class MetaReview < ActiveRecord::Base
  acts_as_processable :dependents => Proc.new { |meta_review| [meta_review.review, meta_review.member] }, :background => true
  acts_as_review
  
  belongs_to :review
  
  named_scope :visible, :joins => "JOIN reviews ON meta_reviews.review_id=reviews.id JOIN stories ON reviews.story_id=stories.id",
    :conditions => {'reviews.status' => ['list', 'feature'], 'stories.status' => ['list', 'feature']}
  
  validates_uniqueness_of :review_id, :scope => :member_id
  
  class << self
    def paginate_given_by_member(member, options = {})
      paginate_with_options(options.merge(:conditions => {'meta_reviews.member_id' => member.id}))
    end

    def paginate_received_by_member(member, options = {})
      paginate_with_options(options.merge(:conditions => {'reviews.member_id' => member.id}))
    end

    def paginate_with_options(options)
      options[:page] ||= 1
      options[:per_page] ||= 10
      options[:joins] = "JOIN reviews ON meta_reviews.review_id=reviews.id JOIN stories ON reviews.story_id=stories.id"
      options[:conditions].merge!({'reviews.status' => ['list', 'feature'], 'stories.status' => ['list', 'feature']})
      options[:order] = "meta_reviews.created_at DESC"
      MetaReview.paginate(options)
#     visible.paginate(options)
    end

    def given_by_member_count(member)
      count_with_options({:conditions => {'meta_reviews.member_id' => member.id}})
    end

    def received_by_member_count(member)
      count_with_options({:conditions => {'reviews.member_id' => member.id}})
    end

    def count_with_options(options)
      options[:joins] = "JOIN reviews ON meta_reviews.review_id=reviews.id JOIN stories ON reviews.story_id=stories.id"
      options[:conditions].merge!({'reviews.status' => ['list', 'feature'], 'stories.status' => ['list', 'feature']})
      MetaReview.count(options)
    end
  end
end
