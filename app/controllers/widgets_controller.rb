## This controller takes care of serving widgets -- both legacy and current
class WidgetsController < ApplicationController
  # caches_page :get_legacy_widget_data, :emulate_iframe_widget
  caches_page :emulate_iframe_widget
  caches_action :get_legacy_widget_data, :cache_path => Proc.new { |c| "#{c.request.host_with_port}#{c.request.request_uri}" }

  include ApplicationHelper
  include LegacyFeedsHelper
  include StoriesHelper

    # Cached subject list
  @@subjects = nil

  # GET /widgets/
  def index
    @@subjects = SocialNewsConfig["topic_subjects"].collect{ |ts| [ ts.keys.first, ts.values.first["name"] ] } if @@subjects.nil?
    @subjects  = @local_site.nil? ? @@subjects : @local_site.subjects.collect { |s| [s.slug, s.name] }

    @topics = Topic.site_topics(@local_site, :conditions => ["topic_volume <= ?", 30], :order => "name")
    @w_params = params[:url] ? get_widget_params(params[:url]) \
                             : {:wt => "topic", :lt => "most_recent", :topic_name => "all_stories", :ct => "", :so => "", :tr_nd => ""}

      # If the request is for a topic that won't be in the topic drop down, simply tack it on!
    if !@w_params[:topic_name].blank? && !["most_recent", "all_stories"].include?(@w_params[:topic_name])
      ts = Topic.find_topic(@w_params[:topic_name], @local_site)
      @topics << ts if (ts.topic_volume > 30)
    end
  end

  # GET /widgets/legacy_index
  def legacy_index
    @topics = Topic.site_topics(@local_site, :conditions => ["topic_volume <= ?", 30], :order => "name")
    @subjects = [
      { "slug" => "world",    "name" => "World" },
      { "slug" => "us",       "name" => "U.S." },
      { "slug" => "politics", "name" => "Politics" },
      { "slug" => "business", "name" => "Business" },
      { "slug" => "scitech",  "name" => "Sci/Tech" },
      { "slug" => "media",    "name" => "Media" },
      { "slug" => "health",   "name" => "Health" }
    ]
  end

  # GET /widgets/preview?<params>
      # Params can be:
      # * widgetName=STRING
      # * widgetFormat=STRING
      # * numStories=INT
      # * width=INT
      # * date=0/1
      # * source=0/1
      # * stars=0/1
      # * rating=0/1
      # * story_type=0/1
      # * authors=0/1
      # * quote=0/1
      # * see_reviews=0/1
      # * review_it=0/1
  def preview
    render(:layout => "widget_iframe")
  end

  # GET /widgets/most_recent-small-skyscraper.htm ... etc.
  def emulate_iframe_widget
    widget_name = params[:widget_name]
    (@base_widget_name, @widget_format) = $1, $2 if widget_name =~ /(.*)-(\w*-\w*)/
    if (@base_widget_name.nil? || @widget_format.nil?)
      render_404 and return
    end
    render(:layout => "widget_iframe")
  end

  # GET /widgets/most_recent.json ... etc.
  def get_legacy_widget_data
    begin
      widget_name = params[:widget_name]
      feed_data   = get_feed_data(widget_name, params[:t_or_s], SocialNewsConfig["widgets"]["stories_per_legacy_widget"])
      widget      = widgetize_listing(feed_data[:feed_params], feed_data[:items])
      @metadata   = widget[:metadata]
      @stories    = widget[:stories]

      respond_to {|format| format.json}
    rescue Exception => e
      logger.error "Bad request for widget: #{widget_name} feed_cat: #{params[:t_or_s]}; Exception is #{e}"
      render_404 and return
    end
  end

  private
  def get_widget_params(w_url)
      # Member widgets
      # Ex: 1. /members/david-fox/reviews
      #     2. /members/david-fox/reviews_with_notes
    if (w_url =~ %r|/members/([^/]*)/(.*)|)
      return {:wt => "member", :who => Member.find_by_slug($1), :lt => $2 }
    end

      # Source widgets
      # Ex: 1. /sources/huffington_post/most_recent
      #     2. /sources/huffington_post/subjects/politics/most_trusted_60/opinion
    if (w_url =~ %r|/sources/([^/]*)/|)
      wt = "source"
      slug = $1
      src = Source.find_by_slug(slug)
      w_url.sub!(%r|/sources/#{slug}|, '')
      if src.nil?
        logger.error "Unknown source widget request with src slug #{slug} for widget url: #{w_url}" 
        flash[:error] = "We could not find your source widget: #{w_url}.  We are displaying the most recent stories widget instead."
        return {:wt => "topic", :lt => "most_recent", :topic_name => "all_stories", :ct => "", :so => "", :tr_nd => "" }
      end
    else
        # Topic widgets 
        # Ex: 1. /stories/most_trusted
        #     2. /subjects/politics/most_trusted_60/opinion
      wt = "topic"
      src = nil
    end

      # Content type
    if (w_url =~ %r|/topics/([^/]*)/|)
      topic_name = $1
      w_url.sub!(%r|/topics/#{topic_name}|, '')
    elsif (w_url =~ %r|/subjects/([^/]*)/|)
      topic_name = $1
      w_url.sub!(%r|/subjects/#{topic_name}|, '')
    else
      topic_name = "all_stories"
      w_url.sub!(%r|/stories/|, '/')  # This will happen only for topic widgets
    end

      # Listing type
    tr_nd = ""
    if w_url =~ %r{^/([^/]*?)(_\d+)?(/|$)}
      lt = $1
      tr_nd = ($2 || "").gsub(/_/, '')
    end
    w_url.sub!(%r|^/#{lt}|, '')
    w_url.sub!(%r|_#{tr_nd}|, '') if !tr_nd.blank?

      # Story type
    ct = ""
    ct = "news" if w_url =~ %r|^/news|
    ct = "opinion" if w_url =~ %r|^/opinion|
    w_url.sub!(%r|/#{ct}|, '') if !ct.blank?

      # Source ownership
    so = ""
    so = "mainstream" if w_url =~ %r|^/mainstream|
    so = "independent" if w_url =~ %r|^/independent|

    return {:wt => wt, :lt => lt, :src => src, :topic_name => topic_name, :ct => ct, :so => so, :tr_nd => tr_nd }
  end
end
