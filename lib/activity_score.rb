module ActivityScore
  DECAY_FACTOR = 10  # 10% decay each cycle

  SCORE_BOOSTS = {
    :nt_pageview     =>   20,
    :target_pageview =>   40,
    :like            =>   80,
    :unlike          =>  -80,
    :email           =>  100,
    :comment         =>  150,
    :member_submit   =>  150,
    :feed_submit     =>  150,
    :story_listed    =>  200,
    :staleness       =>   -5,
    :review          =>  400
  }

  def self.boost_score(story, boost_type, opts={})
    opts[:member]  ||= nil 
    opts[:obj]     ||= nil
    opts[:url_ref] ||= nil

    m = opts[:member]
    mrating = (m && m.rating) ? m.rating : 1.0
    obj = opts[:obj]
    case boost_type
      when :email
        boost = SCORE_BOOSTS[:email]
      when :feed_submit
        boost = SCORE_BOOSTS[:feed_submit] * (2*story.autolist_score - 1.0) # normalize to 0.50
      when :member_submit
        boost = SCORE_BOOSTS[boost_type] * mrating / 3.5  # Normalize to 3.5 member rating
        ActivityEntry.create(:member_id => m.id, :activity_type => 'Story', :activity_id => story.id, :referrer_code => opts[:url_ref])
      when :story_listed
        ae = ActivityEntry.find(:first, :conditions => {:activity_type => 'Story', :activity_id => story.id})
        if ae.nil?
          ActivityEntry.create(:member_id => m.id, :activity_type => 'Story', :activity_id => story.id, :referrer_code => opts[:url_ref])
        else
          # Overwrite entry from earlier submit!  Otherwise, we'll have 2 members submitting the same story
          # (first, the member who posted it from wherever into pending state, next, the member who took it to listed state!)
          # But, accumulate referrer codes (without duplication)
          ref_code = (ae.referrer_code.blank? || opts[:url_ref] == ae.referrer_code) ? opts[:url_ref] : "#{ae.referrer_code},#{opts[:url_ref]}"
          ae.update_attributes({:updated_at => Time.now, :member_id => m.id, :referrer_code => ref_code})
        end
        boost = SCORE_BOOSTS[boost_type] * (story.status == Story::FEATURE ? 2 : 1)
        # Account for story staleness.  Two factors (a) how long it has been in our db (b) when we estimate it was published
        staleness = ((Time.now - story.created_at) / 3600).round + ((Time.now.beginning_of_day - story.story_date.beginning_of_day) / 3600).round
        boost += (SCORE_BOOSTS[:staleness] * staleness)
      when :review
        # Boost depends on current story rating, current review rating, total # of reviews, and reviewer's rating
        ActivityEntry.create(:member_id => m ? m.id : nil, :activity_type => 'Review', :activity_id => obj.id, :referrer_code => opts[:url_ref])
        boost = SCORE_BOOSTS[:review] * (obj.rating / (story.rating || 1.0)) * mrating / 3.5
      when :comment
        # For comments, activity entries are created in the comments after create filter
        # This is because comments can be on topics, subjects, sources, as well as stories
        # whereas this method is called only for stories
        boost = SCORE_BOOSTS[boost_type] * mrating / 3.5  # Normalize to 3.5 member rating
      when :like
        ActivityEntry.create(:member_id => m.id, :activity_type => 'Save', :activity_id => obj.id, :referrer_code => opts[:url_ref])
        boost = SCORE_BOOSTS[boost_type] * mrating / 3.5  # Normalize to 3.5 member rating
      when :unlike
        ActivityEntry.find(:first, :conditions => {:member_id => m.id, :activity_type => 'Save', :activity_id => obj.id}).destroy
        boost = SCORE_BOOSTS[boost_type] * mrating / 3.5  # Normalize to 3.5 member rating
      else
        boost = SCORE_BOOSTS[boost_type] * mrating / 3.5  # Normalize to 3.5 member rating
    end
    story.update_attribute("activity_score", story.activity_score + boost)
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception #{e} boosting score of #{story.id} for #{boost_type} with member #{m ? m.id : "guest"} and object #{obj ? obj.id : "none"}"
  end
end
