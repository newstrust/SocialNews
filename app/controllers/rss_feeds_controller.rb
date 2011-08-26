## This controller takes care of serving legacy rss feeds
class RssFeedsController < ApplicationController
  # caches_page :get_legacy_rss_feed
  caches_action :get_legacy_rss_feed, :cache_path => Proc.new { |c| "#{c.request.host_with_port}#{c.request.request_uri}" }

  include ApplicationHelper
  include StoriesHelper
  include LegacyFeedsHelper

  # GET /rss/most_recent.xml ... etc.
  def get_legacy_rss_feed
    begin
      feed_name = params[:feed_name]
      if params[:feed_cat].blank?
        feed_name = case feed_name
          when "index" then "most_recent"
          when /(.*)_(ind|msm)/ then "#{$1}/#{$2 == "ind" ? "independent" : "mainstream"}"
          else feed_name
        end
        redirect_to "/stories/#{feed_name}.xml", :status => :moved_permanently and return
      elsif params[:feed_cat] == "subjects"
        redirect_to "/subjects/#{feed_name}/most_recent.xml", :status => :moved_permanently and return
      else
        tp = @local_site ? "#{@local_site.name} " : ""
        @feed_data = get_feed_data(feed_name, params[:feed_cat], 25)  ## FIXME: parameterize the 25
        @feed_data[:feed_title] = tp + get_rss_feed_title(@feed_data[:feed_params], params[:feed_cat])
      end

      respond_to {|format| format.rss}
    rescue Exception => e
#  No need to log these ... lot of bad urls coming in ... simple gets in the way of log monitoring
      logger.error "Bad feed request: '#{feed_name}' feed_cat: '#{params[:feed_cat]}'; Exception is #{e}; #{e.backtrace.inspect}"
      render_404 and return
    end
  end
end
