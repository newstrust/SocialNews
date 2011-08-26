class PagesController < ApplicationController
  def search
    render_404 and return if visitor_is_bot? && params[:page] && (params[:page].to_i > 40)

    respond_to do |format|
      format.html do
       if empty_query?
         render :action => 'search'
       else
         render :action => 'results' if search_for(params[:id] || params[:q])
       end
      end
    end
  end

  def shorten_url
    # Only NT-originating requests are respected
    render_404 and return unless request.env["SERVER_NAME"] =~ /#{SocialNewsConfig["app"]["domain"]}|localhost/

    begin
      url = params[:url] ? ShortUrl.shorten_url(params[:url]) : ""
    rescue Exception => e
      logger.error "Exception #{e} shortening url #{params[:url]}!"
      url = params[:url]
    end
    respond_to do |format|
      format.html { render :inline => url }
      format.js { render :json => { :url => url }.to_json }
    end
  end

  def scoped_search
    render_404 and return if visitor_is_bot? && params[:page] && (params[:page].to_i > 40)

    if params[:type] && !empty_query? && %w(story source member).include?(params[:type].downcase)
      model = params[:type].classify.constantize
      opts = pagination_params(:per_page => 25)
      opts.merge!(:sort_mode => :extended, :order => "sort_field DESC, @relevance DESC" ) if params[:type].downcase == "story"
      respond_to do |format|
        @results = model.search(params[:q], opts)
        format.html{render :action => 'results'}
      end
    else
      flash[:error] = "Nothing to do here."
      redirect_to search_path
    end
  end
  
  # map globbed route onto template dir
  def show
    path_array = params[:path].collect{|pi| pi.downcase.scan(/^([^.]+)/).flatten.first}.compact # throw out extensions
    path_array.delete('index') # rashly throw out any component called index
    page_tpl_path = "#{params[:section].downcase}" + (path_array.empty? ? "" : "/#{path_array.join('/')}")
    if @local_site && File.exists?("#{RAILS_ROOT}/app/views/pages/local_sites/#{@local_site.slug}/#{page_tpl_path}.html.erb")
      page_tpl = "pages/local_sites/#{@local_site.slug}/#{page_tpl_path}"
    else
      page_tpl = "pages/#{page_tpl_path}"
    end
    render :template => page_tpl, :layout => (params[:popup] ? "popup" : nil)
  rescue ActionView::MissingTemplate
    render_404
  end

  def aliases
    redirect_to request.request_uri.sub(/#{params[:from]}/, params[:to])
  end

  def subject_aliases
    redirect_to request.request_uri.sub(%r|^(/subjects)?/other|, "#{$1}/extra") and return if request.request_uri =~ %r|^(/subjects)?/other|
    render_404
  end

  def health_check
    File.read "#{RAILS_ROOT}/config/database.yml" 
    render :text => "OK", :layout => false
  rescue Exception => e
    render_error_by_code(500)
  end

  def bj_check
    latest_job = Bj.table.job.find(:first, :conditions => {:state => "finished"}, :order => "finished_at DESC")
    render :text => "Most recent BJ job finished at #{latest_job.finished_at}.  Command was #{latest_job.command}", :layout => false
  rescue Exception => e
    render_error_by_code(500)
  end

  protected

  def search_for(str)
    opts = pagination_params(:per_page => 25)
    @results = ThinkingSphinx::Search.search(str, opts.merge({:sort_mode => :extended, :order => "sort_field DESC, @relevance DESC" }))
    if (opts[:page].to_i == 1)
        # SSS: Pay attention folks!
        # 0. If we are on the first page, issue two other additional queries 
        #    -- to ensure that topic and subject results appear first!
        # 1. ThinkingSphinx returns a ThinkingSphinx::Collection type object
        #    If I do an (x + y + z) on these classes, the collection object becomes an array
        #    which will_paginate cannot work with!  So, insert the topic & subject collections
        #    into the all_results collection and flatten the result. ThinkingSphinx::Collection
        #    retains its type with these operations.
        # 2. Uniquify so that if all_results already has the same topics/subjects, they go away!
      @results.insert(0, Topic.search(str, opts).reject { |t| t.local_site != @local_site })
      @results.insert(0, Subject.search(str, opts).reject { |t| t.local_site != @local_site })
      @results.flatten!
      @results.uniq!
    end
    @results
  rescue Riddle::ResponseError => e
    flash[:error] = "We encountered an unexpected error processing your request.  We'll look into this at the earliest.  Sorry for the inconvenience!"
    logger.error "Exception #{e} processing search request with params: #{opts.inspect}; Member is #{current_member ? current_member.id : (visitor_is_bot? ? 'BOT' : 'guest')}"
    render(:action => 'search_error') and return false
  rescue ThinkingSphinx::ConnectionError
    flash[:error] = "There was an error connecting to the search engine database."
    render(:action => 'search_error') and return false
  end
end
