# SSS: This is a convenience class to generate activity feeds easily without having to do complicated gymnastics across tables
class ActivityEntry < ActiveRecord::Base
  belongs_to :member
  belongs_to :activity, :polymorphic => true

  def self.most_recent_member_activity(m)
    ActivityEntry.find(:first, 
                       :conditions => ["member_id = ?", m.id], 
                       :order => "updated_at DESC",
                       :include => {:member => [:image, :facebook_connect_settings, :twitter_settings]},
                       :limit => 1)
  end

  def self.activity_object_hash(entries)
    h = {"Save" => {}, "Review" => {}, "Comment" => {}, "Story"=> {}}

    save_ids = entries.reject { |ae| ae.nil? || ae.activity_type != 'Save'}.map(&:activity_id)
    Save.find_all_by_id(save_ids, :include => {:story => [:submitted_by_member, :sources]}).each { |l| 
      h["Save"][l.id] = l
    }

    review_ids = entries.reject { |ae| ae.nil? || ae.activity_type != 'Review'}.map(&:activity_id)
    Review.find_all_by_id(review_ids, :include => [:meta_reviews, {:story => [:submitted_by_member, :sources]}]).each { |r| 
      h["Review"][r.id] = r
    }

    comment_ids = entries.reject { |ae| ae.nil? || ae.activity_type != 'Comment'}.map(&:activity_id)
    Comment.find_all_by_id(comment_ids).each { |c|
      h["Comment"][c.id] = c
    }

    post_ids = entries.reject { |ae| ae.nil? || ae.activity_type != 'Story'}.map(&:activity_id)
    Story.find_all_by_id(post_ids, :include => [:submitted_by_member, :sources]).each { |s| 
      h["Story"][s.id] = s
    }

    return h
  end

  def self.reject_hidden_entries(activities)
    activities.reject! { |ae|
      # Leave nil activity entries as is -- shows up in follower activity entries if someone I follow or someone who follows me has not been active.
      if ae.nil?
        false
      else
        a = ae.activity
        a.nil? || # SSS FIXME: How can this be?
        (ae.activity_type == 'Comment' && a.commentable.respond_to?(:status) && a.commentable.status == Status::HIDE) ||
        (ae.activity_type == 'Review' && a.status == Status::HIDE) ||
        (ae.activity_type == 'Story' && a.status == Status::HIDE)
      end
    }
  end
end
