class FollowedItemsController < ApplicationController
  include FacebookConnectHelper
  include TwitterHelper

  # Only javascript POST allowed -- can only be used as an ajax call at this point.
  # Follow feature -- this action acts as a toggle!
  def follow
    m = get_follower
    render :json => { :success => false, :error => "No logged in member found OR you are trying to modify mynews settings for another member!" }.to_json and return if m.nil? 

    follower = m
    f_id     = params[:followable_id].to_i
    f_type   = params[:followable_type].downcase.capitalize if params[:followable_type]
    if f_id.nil? || f_type.nil?
      error = "No parameters provided.  What should I follow?"
    elsif !["Member", "Topic", "Feed", "Source"].include?(f_type)
      error = "Cannot follow a #{f_type}.  Only members, topics, feeds, or sources, can be followed."
    elsif f_type == "Member" && follower.id == f_id
      error = "Cannot follow yourself!"
    else
      fi = FollowedItem.toggle(follower.id, f_type, f_id)
      if fi.nil? && f_type == 'Feed'
        # Turn off autofetch on twitter & facebook feeds!
        # 1. No one except the owner can follow fb and twitter feeds => no need to check the identity of the unfollower (has to be the owner)

        ## This comment is no longer true since we've locked down access to twitter feeds too!
        ## # 2. Others can follow a twitter feed, so check for ownership.  Basically, if owner unfollows
        ## #    the feed is no longer fetched for anyone (which means we shouldn't let twitter feeds be
        ## #    followable by others either).
        f = Feed.find(f_id)
        f.update_attribute(:auto_fetch, 0) if f.is_private?
#        if f.is_fb_user_newsfeed?
#          f.update_attribute(:auto_fetch, 0)
#        elsif f.is_twitter_user_newsfeed? && f.member_profile_id == m.id
#          f.update_attribute(:auto_fetch, 0)
#        end
      end
      error = nil
    end
    respond_to do |format|
      format.js do
        if error.nil?
          render :json => { :success => true, :created => !fi.nil? }.to_json
        else
          render :json => { :success => false, :error => error }.to_json
        end
      end
    end
  end

  def bulk_follow
    m = get_follower
    render :json => { :success => false, :error => "No logged in member found OR you are trying to modify mynews settings for another member!" }.to_json and return if m.nil? 

    fids = params[:follow_ids]
    if fids
      follow_type = params[:follow_type]
      model = follow_type.capitalize.constantize
      resp = fids.keys.collect { |k|
        if fids[k] == '1'
          item = model.send(:find, k)
          if item
            FollowedItem.add_follow(m.id, follow_type, k)
            follow_item_opts(follow_type, item, m, true)
          end
        end
      }.compact
    else
      resp = []
    end
    render :json => { :success => true, :items => resp }.to_json
  end

  def get_follower
    m = current_member

    if params[:follower_id] && (params[:follower_id].to_i != m.id)
      # member M1 (m) is trying to update follower list of member M2 (params[:follower_id]) where M1 and M2 are not the same
      #
      # Don't allow member M1 to update follower lists of member M2 except when
      # (a) M2 is a dummy member of a group AND (b) M1 is staff of host of that group

      f_id = params[:follower_id].to_i
      sg   = SocialGroupAttributes.find(:first, :conditions => {:mynews_dummy_member_id => f_id})
      if sg && m.has_host_privilege?(sg.group, :staff, @local_site)
        m = Member.find(f_id)
      else
        m = nil
      end
    end

    return m
  end
end
