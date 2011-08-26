class SourceStats < ActiveRecord::Base
  belongs_to :source
  belongs_to :local_site

  named_scope :for_site,   lambda { |s| { :conditions => { :local_site_id => s ? s.id : nil } } }
  named_scope :for_source, lambda { |m| { :conditions => { :source_id => m.id } } }

  def self.source_review_stats(source_id, local_site_id=nil)
    srs = SourceReview.find(:all, 
                            :select => "source_reviews.rating as sr, members.rating as mr", 
                            :joins => [:member], 
                            :conditions => "source_reviews.rating IS NOT NULL AND source_id = #{source_id} AND local_site_id#{local_site_id.nil? ? " IS NULL" : "=#{local_site_id}"}")
    num, den = 0.0, 0.0
    srs.each { |r| sr = r.sr.to_f; mr = r.mr.to_f; num += sr * mr; den += mr }
    [srs.count, den != 0.0 ? num/den : 0.0]
  end

  # group is not used, but it is passed in by ProcessJob, so we need to include it in the argument list
  def update_review_stats(group=nil)
    stats = SourceStats.source_review_stats(self.source_id, self.local_site_id)
    self.update_attributes("source_reviews_count" => stats[0], "review_rating" => stats[1])
  end

  def update_stats
    ls_join = "JOIN taggings ON taggings.taggable_id=reviews.story_id AND taggings.taggable_type='Story' AND taggings.tag_id = #{local_site.constraint_id}"
    joins = "JOIN authorships ON reviews.story_id=authorships.story_id #{ls_join}"
    conds = {"authorships.source_id" => source.id, "reviews.status" => [Review::LIST, Review::FEATURE]}
    self.story_reviews_count = Review.count(:joins => joins, :conditions => conds)

    ls_join = "JOIN taggings ON taggings.taggable_id=stories.id AND taggings.taggable_type='Story' AND taggings.tag_id = #{local_site.constraint_id}"
    joins = "JOIN authorships ON stories.id=authorships.story_id #{ls_join}"
    conds = ["authorships.source_id = ? AND stories.status IN (?) AND stories.reviews_count >= ?",
             source.id, [Story::LIST, Story::FEATURE], SocialNewsConfig["min_reviews_for_story_rating"]]
    reviewed_stories = Story.find(:first, :select => "count(*) AS count_all, avg(stories.rating) AS avg_rating", :joins => joins, :conditions => conds)
    self.reviewed_stories_count = reviewed_stories.count_all
    self.rating = reviewed_stories.avg_rating
    save!
  end
end
