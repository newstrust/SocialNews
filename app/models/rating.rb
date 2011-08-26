#
# Rating
#
# The numeric component of a review (integer)
#

class Rating < ActiveRecord::Base
  belongs_to :ratable, :polymorphic => true
  
  validates_presence_of :value
  validates_uniqueness_of :criterion, :scope => [:ratable_id, :ratable_type]

  def self.init_label_settings(yaml_config)
    h = {}
    yaml_config["quality"].each { |metric, labels| h[metric] = {:positive => labels["positive"].downcase, :negative => labels["negative"].downcase } }
    yaml_config["popularity"].each { |metric, vals| h[metric] = {:positive => "yes", :negative => "no"} }
    return h
  end

  LABEL_SETTINGS = self.init_label_settings(SocialNewsConfig["label_review_forms"]["review_labels"])

  # constant util
  class << self
    def criterion(criterion, criterion_type)
      SocialNewsConfig["rating_criteria"][criterion_type][criterion]
    end

    def criteria_keys_by_type(criterion_type)
      SocialNewsConfig["rating_criteria"][criterion_type].keys
    end
    
    # for display logic. optionally sort array if list_position_key is specified (for "quality" only)
    def each_criterion_by_type(criterion_type, list_position_key="display")
      SocialNewsConfig["criteria_order"][criterion_type][list_position_key].each do |form_level|
        form_level_key = form_level.keys.first
        criteria_keys = form_level.values.first
        criteria_keys.each do |criterion_key|
          criterion = self.criterion(criterion_key, criterion_type)
          yield(criterion_key, criterion, form_level_key)
        end
      end
    end

    def each_source_criterion
      SocialNewsConfig["source_rating_criteria"].each do |key, rc|
        yield(key, rc)
      end
    end

    def quality_labels(form_type)
      SocialNewsConfig["label_review_forms"]["form_levels"]["quality"][form_type].each do |form_settings|
        form_level = form_settings.keys.first
        metrics    = form_settings.values.first
        metrics.each { |m| yield(form_level, m, SocialNewsConfig["label_review_forms"]["review_labels"]["quality"][m]) }
      end
    end

    def popularity_questions
      SocialNewsConfig["label_review_forms"]["form_levels"]["popularity"]["form"].each do |form_settings|
        form_level = form_settings.keys.first
        metrics    = form_settings.values.first
        metrics.each { |m| yield(form_level, m, SocialNewsConfig["label_review_forms"]["review_labels"]["popularity"][m]) }
      end
    end

    def review_label(metric, val)
      val.blank? ? nil : ((val < 3) ? LABEL_SETTINGS[metric][:negative] : LABEL_SETTINGS[metric][:positive])
    end

    def ratings_to_labels(ratings_hash)
      labels_hash = {}
      ratings_hash.each { |k,v|
        val = v["value"] ? v["value"].to_i : nil
        next if val.nil?

        labels_hash[k] = (val < 3) ? LABEL_SETTINGS[k][:negative] : LABEL_SETTINGS[k][:positive]
      }
      return labels_hash
    end

    # SSS: We are using polar ratings here (2 & 4).
    def labels_to_ratings(labels_hash)
      ratings_hash = {}
      labels_hash.each { |k,v|
        next if v.blank?

        v.downcase!
        ls = LABEL_SETTINGS[k]
        if ls[:positive] == v
          rating = 4
        elsif ls[:negative] == v
          rating = 2
        else
          raise Exception.new("Unknown value #{v} for metric #{k}")
        end
        ratings_hash[k] = {"criterion" => k, "value" => rating}
      }
      return ratings_hash
    end
  end
  
end
