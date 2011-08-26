class Admin::StoriesController < Admin::AdminController
  layout 'admin'
  grant_access_to [:editor, :newshound]

  include StoriesHelper

  def merge_stories
    keep_id = params[:keep_id]
    merge_id = params[:merge_id]
    if (keep_id.blank? || merge_id.blank?)
      flash[:error] = "Please fill in both story IDs."
      redirect_to merge_tool_admin_stories_path
    elsif (keep_id == merge_id)
      flash[:error] = "You cannot merge a story (#{merge_id}) with itself (#{keep_id})!<br>That would be like a snake eating its tail, and would lead to the end of this world!<br>Please enter two DIFFERENT ids!"
      redirect_to merge_tool_admin_stories_path
    else
      Story.find(keep_id).swallow_dupe(merge_id, current_member)

        # Reload the story
      @keep = Story.find(keep_id)

        # Notices
      flash[:notice] = "Merged story #{merge_id} into story #{keep_id}."
      flash[:notice] += "<br>Note that the story you decided to keep is a hidden story." if (@keep.status == 'hide')

        # We deleted the other story!
      begin
        @hide = Story.find(merge_id)
      rescue Exception => e
        flash[:notice] += "<br/>Deleted #{merge_id} because the urls were identical!"
      end

      flash.discard
    end
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.to_s
    redirect_to merge_tool_admin_stories_path
  end

  def autofetch_summary
    # Disabled for now
    render_404 and return

#    @feeds = Feed.find(:all, :conditions => {:auto_fetch => true}, :order => "feeds.name")
#
#      # No pagination, and all queued stories in the default timespan!
#      # Fetch taggings & feeds immediately to avoid zillion db queries to fetch them right after this
#    all_stories    = find_queued_stories(@local_site, {:paginate => false, :all => true, :include => [:story_feeds, :taggings, :authorships]})
#    @topic_stats   = all_stories.inject({}) { |counts,s| s.taggings.inject(counts) { |h,t| t = t.tag; h[t.id] = 1 + (h[t.id] || 0) if t.class == Topic; h } }
#    @subject_stats = all_stories.inject({}) { |counts,s| s.taggings.inject(counts) { |h,t| t = t.tag; h[t.id] = 1 + (h[t.id] || 0) if t.class == Subject; h } }
##    @src_stats     = all_stories.inject({}) { |counts,s| s.authorships.inject(counts) { |h,a| h[a.source.ownership] = 1 + (h[a.source.ownership] || 0); h } }
#    @stype_stats   = all_stories.inject({}) { |counts,s| stype = s.story_type.blank? ? "" : s.story_type.strip.downcase; counts[stype] = 1 + (counts[stype] || 0); counts }
#    @feed_stats    = all_stories.inject({}) { |counts,s| s.story_feeds.inject(counts) { |h,f| h[f.feed_id] = 1 + (h[f.feed_id] || 0); h } }
#
#    render :layout => "application"
  end

  # GET
#  def all_queued_stories
#    all_stories    = Story.list_stories(get_listing_options({:all => true, :listing_type => :queued_stories, :timespan => params[:timespan] || 1}))
#    @topic_stats   = all_stories.inject({}) { |counts,s| s.topics.inject(counts) { |h,t| h[t.id] = 1 + (h[t.id] || 0); h } }
#    @subject_stats = all_stories.inject({}) { |counts,s| s.subjects.inject(counts) { |h,t| h[t.id] = 1 + (h[t.id] || 0); h } }
#    @stype_stats   = all_stories.inject({}) { |counts,s| stype = s.story_type.blank? ? "" : s.story_type.strip.downcase; counts[stype] = 1 + (counts[stype] || 0); counts }
#    @src_stats     = all_stories.inject({}) { |counts,s| s.authorships.inject(counts) { |h,a| h[a.source.ownership] = 1 + (h[a.source.ownership] || 0); h } }
#    @feed_stats    = all_stories.inject({}) { |counts,s| s.story_feeds.inject(counts) { |h,f| h[f.feed_id] = 1 + (h[f.feed_id] || 0); h } }
#    @total_stories = all_stories.size
#
#    # split stories by subject!
#    @all_stories = find_queued_stories(params.merge({:paginate => true}))
#    @subj_stories = @all_stories.inject({}) { |h,s| s.subjects.each { |subj| h[subj.id] ||= []; h[subj.id] << s }; h }
#    render :layout => "application"
#  end

  # GET
  def mass_edit_queued_stories
    more_opts = { :paginate          => true,
                  :listing_type_opts => @local_site ? {:min_score => nil} : nil, # Explicitly turn off min-score constraint for the local site
                  :source_ownership  => params[:source_ownership],
                  :source_rating_class => @local_site ? nil : "trusted" }
    @stories = find_queued_stories(@local_site, params.merge(more_opts))
  end

  # POST
  def mass_update_queued_stories
    flash[:notice] = mass_update_stories(params[:stories])
    redirect_to admin_stories_url
  end
end
