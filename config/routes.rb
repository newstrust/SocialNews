def define_listing_routes(router, url_prefix, url_params)
    # Seed the process with the incoming url_prefix
    # In each iteration of the loop, all elements of the route list are extended with the new param and added back to the list
    #
    # ["a"] --> ["a", "a/b"] --> ["a", "a/b", "a/c", "a/b/c"] --> ["a", "a/b", "a/c", "a/b/c", "a/d", "a/b/d", "a/c/d", "a/b/c/d"] .. and so on ...
  route_suffixes = url_params.inject([url_prefix]) { |lst, p| lst += lst.collect { |e| e + p[1] + ":" + p[0] }}

    # Compute any regexp constraints for each param in that route
    # Push each route candidate through the router 
  route_suffixes.each { |rs|
    route_opts = url_params.inject({}) { |h, p| h[p[0].to_sym] = p[2] if rs =~ /#{p[0]}/; h }
    router.connect(rs, route_opts)
  }
end

ActionController::Routing::Routes.draw do |map|
  map.home '', :controller => 'home'
  map.connect "mynews", :controller => "mynews", :action => "mynews_home"
  map.connect "mynetwork", :controller => "members", :action => "mynetwork"
  map.connect "myaccount", :controller => "members", :action => "my_account"

  valid_subjects_regexp = Regexp.new(TopicRelation.topic_subjects.join('|'))

  listing_query_params = [
     [ "content_type",     "/",                    /video|audio/ ],
     [ "story_type",       "/",                    /news|opinion/ ],
     [ "source_ownership", "/",                    /mainstream|independent/ ],
#
# -- not yet supported in the widget index, so commenting these off till we need these options!
#
#     [ "edit_priority",    "/editorial_priority/", /\d{1}/ ],
#     [ "min_reviews",      "/min_reviews/",        /\d{1,2}/ ],
     [ "format",           ".",                    /xml|json|js/ ]
  ]

    # We need the :listing_type regexp to prevent other urls matching against these rules! (ex: GET /stories/134)
  map.with_options :controller => "stories", :action => "index", :listing_type => /least_trusted(_\d+)?|most_recent|most_trusted(_\d+)?|for_review|recent_reviews|all_rated_stories/ do |stories|
      # regular story listings
    define_listing_routes(stories, "/stories/:listing_type", listing_query_params)

      # topic story listings
    define_listing_routes(stories, "/topics/:t_slug/:listing_type", listing_query_params)

      # group story listings
    define_listing_routes(stories, "/groups/:g_slug/:listing_type", listing_query_params)

      # subject story listings
      # we are using the :s_slug regexp to catch invalid subject listing request -- but strictly not required
    stories.with_options :s_slug => valid_subjects_regexp do |subj_stories|
      define_listing_routes(subj_stories, "/subjects/:s_slug/:listing_type", listing_query_params)
    end

      # clean urls for source listings (no source ownership or content type listings)
    define_listing_routes(stories, "/sources/:source/:listing_type", listing_query_params.reject {|x| ['source_ownership','content_type'].include?(x[0])})
    define_listing_routes(stories, "/sources/:source/topics/:t_slug/:listing_type", listing_query_params.reject {|x| ['source_ownership','content_type'].include?(x[0])})
    define_listing_routes(stories, "/sources/:source/subjects/:s_slug/:listing_type", listing_query_params.reject {|x| ['source_ownership','content_type'].include?(x[0])})
  end

  map.with_options :controller => "members", :action => "reviews", :review_type => /reviews_with_notes/ do |reviews|
    define_listing_routes(reviews, "/members/:id/:review_type", listing_query_params[2..2])
  end

    # clean urls for member review listings -- full blown support for all kinds of filters not present yet!
  #listing_query_params.insert(0, [ "listing_type", "/", /most_recent|most trusted_(\d+)?/ ])
  #map.with_options :controller => "members", :action => "reviews", :review_type => /reviews(_with_notes)?/ do |reviews|
  #  define_listing_routes(reviews, "/members/:id/:review_type/topics/:t_slug", listing_query_params)
  #  define_listing_routes(reviews, "/members/:id/:review_type/topics/:s_slug", listing_query_params)
  #end

  # basic resources: stories, reviews, sources, topics, subjects
  map.resources :topics, :collection => { :all => :get, :featured => :get }, :member => { :ajax_stories => :get }

  # we need the :subject_id regexp to prevent other urls matching against these rules! (ex: GET /widgets)
  map.subject ':subject_id', :controller => 'subjects', :action => 'show', :subject_id => valid_subjects_regexp
  map.connect ':subject_id/ajax_stories', :controller => 'subjects', :action => 'ajax_stories', :subject_id => valid_subjects_regexp

  # Legacy-ish... Chucks the story in the db & redirects to toolbar now.
  map.submit_story 'submit', :controller => 'stories', :action => 'post' #, :conditions => {:method => :post} # SSS: looks like we want easy posting!
  map.post_story   'post', :controller => 'stories', :action => 'post' #, :conditions => {:method => :post} # SSS: looks like we want easy posting!

  map.resources :stories,
    :member => {:info => :get, :save => :post, :record_click => :post, :edit_pending => :get, :toolbar => :get, :fetch_metadata => :post, :destroy_image => :delete, :destroy_video => :delete, :short_url => :post},
    :collection => {:activity_listing => :get, :autopopulate => :post} do |stories|
    stories.resources :reviews, :member => { :meta_review => :post }, :name_prefix => nil
  end
    ## FIXME: we are violating REST here, but, what to do? 
    ## we have to support save links in email newsletters & widgets while user is logged in / logged out
  map.connect "stories/:id/save", :controller => 'stories', :action => 'save', :method => :get 

  map.overall_rating 'reviews/overall_rating', :controller => 'reviews', :action => 'overall_rating'

  map.resources :sources,
                :collection => {
                  :trusted => :get,
                  :rate_sources => :get,
                  :rate_by_medium => :get,
                  :list   => :get,
                  :search => :any  # on IE6/IE7, we are getting a POST!
                },
                :member => { 
                  :ajax_stories => :get,
                  :edit_source_review => :get,
                  :source_reviews => :get
                }

  # Source Reviews
  map.resources :source_reviews

  map.with_options :controller => 'widgets', :method => :get do |widgets|
      # index page routes
    widgets.widgets_index "widgets"
    widgets.widgets_preview "widgets/preview", :action => 'preview'

      # legacy url support
    widgets.connect "widgets/index.htm", :action => 'index'
    widgets.connect "widgets/samples",   :action => 'index'
  end

  # For the feed fetcher to post its feed fetch status
  map.connect "feeds/feed_fetch_status", :controller => "feeds", :action => "feed_fetch_status", :method => :post
  map.connect "feeds/num_completed_feeds", :controller => "feeds", :action => "num_completed_feeds", :method => :get
  map.connect "feeds/all", :controller => "feeds", :action => "all", :method => :get

  # For feed pages, provide todays_feeds routes before REST routes because feeds/today will conflict with feeds/:id route
  map.with_options :controller => "feeds", :action => "todays_feeds", :method => :get do |feeds|
    feeds.todays_feeds_feeds       "feeds/today"
    feeds.todays_topic_feeds_feeds "feeds/:ts_slug", :requirements => { :ts_slug => /[a-z](\w|_|-)+/i }
    feeds.connect                  "feeds/today.:format"
    feeds.connect                  "feeds/:ts_slug.:format", :requirements => { :ts_slug => /[a-z](\w|_|-)+/i }
  end
  map.resources :feeds, :member => { :show => :get, :ajax_stories => :get }
  map.resources :groups, :member => { :ajax_stories => :get, :join_group => :post, :leave_group => :post, :members => :get }
  map.resources :flags

  # members, sessions, openid support
  map.resource :sessions, :collection => { 
    :resend_activation => :get,
    :resending_activation => :post,
    :forgot_password => :get, 
    :reset_password => :post 
  }
  map.open_id_complete           'sessions', :controller => "sessions", :action => "create", :requirements => { :method => :get }
  map.open_id_complete_on_member 'create_members',  :controller => "members",  :action => "create", :requirements => { :method => :get }  

  # My News: listings + settings
  map.connect     "/members/:member_id/my_news",        :controller => "mynews", :action => "mynews"
  map.mynews      "/members/:member_id/mynews",         :controller => "mynews", :action => "mynews"
  map.mynews_rss  "/members/:member_id/mynews.:format", :controller => "mynews", :action => "stories"
  map.mynews_ajax "/members/:member_id/mynews/stories", :controller => "mynews", :action => "stories"
  map.connect     "/members/:member_id/mynews/stories/:follow_type/:follow_id", :controller => "mynews", :action => "stories"
  ["update_setting", "update_settings", "last_visit_at"].each { |a|
    map.send("mynews_#{a}", "/members/:member_id/mynews/#{a}", :controller => "mynews", :action => a, :conditions => {:method => :post})
  }

  # My News: follow / unfollow
  map.follow_item "/mynews/follow_item.:format", :controller => "followed_items", :action => "follow", :conditions => {:method => :post}, :requirements => { :format => /js/ }
  map.bulk_follow "/mynews/bulk_follow.:format", :controller => "followed_items", :action => "bulk_follow", :conditions => {:method => :post}, :requirements => { :format => /js/ }

  map.resources :members,
    :member => { 
      :last_active_at        => :post,
      :edit_account          => :get,
      :mynetwork             => :get,
      :network_activity_ajax_listing => :get,
      :followers_activity_ajax_listing => :get,
      :followed_members_activity_ajax_listing => :get,
      :comments              => :get,
      :meta_reviews_given    => :get,
      :meta_reviews_received => :get, 
      :stats_dashboard       => :get,
      :reviews               => :get,
      :picks                 => :get,
      :submissions           => :get,
      :destroy_image         => :delete,
      :tweet                 => :post,
      :publish_reviews_and_posts => :post
    },
    :collection => { 
      :accept_invitation    => :get, 
      :accepting_invitation => :put, 
      :invite               => :get,
      :display_invitation   => :get,
      :inviting             => :post,
      :my_account           => :get,
      :me                   => :get,
      :search               => :any, # on IE6/IE7, we are getting a POST!
      :login_available      => :get,
      :process_dupe_reviews => :get,
      :update_dupe_reviews  => :post,
      :record_fb_stream_post => :post,
      :activate             => :get,
      :trusted              => :get
    } do |members|
      members.resources :openid_profiles
  end
  map.welcome ':welcome_page', :controller => 'members', :action => 'welcome', :welcome_page => /(start)|(welcome(\.htm)?)/
  map.signup 'signup', :controller => 'members', :action => 'new'
  map.signup 'signup/:partner_id', :controller => 'members', :action => 'default_invite'

  # Facebook connect routes
  ["init_activation", "activate", "new_account", "logout", "link_accounts", "link_member", "login_and_link", "unlink", "cancel", "import_picture", "invite_friends", "record_invitations" ].each { |a|
    map.send("fb_#{a}", "fb_connect/#{a}", {:controller => "facebook_connect", :action => a })
  }
  ["followable_friends", "update_extended_perms"].each { |a|
    map.send("fb_#{a}", "fb_connect/#{a}.js", {:controller => "facebook_connect", :action => a })
  }
  # Facebook connect from the toolbar
  map.fb_activate_from_toolbar "fb_connect/activate_from_toolbar/:story_id", {:controller => "facebook_connect", :action => "activate" }
  map.fb_unfollow_newsfeed "facebook/unfollow_newsfeed", :controller => "facebook_connect", :action => "unfollow_newsfeed"

  # Named twitter routes
  map.twitter_authenticate "twitter/authenticate", :controller => "twitter", :action => "authenticate"
  map.twitter_unlink "twitter/unlink", :controller => "twitter", :action => "unlink"
  map.twitter_unfollow_newsfeed "twitter/unfollow_newsfeed", :controller => "twitter", :action => "unfollow_newsfeed"
  map.connect "twitter/follow_newsfeed.js", :controller => "twitter", :action => "follow_newsfeed", :conditions => {:method => :post}
  map.connect "twitter/followable_friends.js", :controller => "twitter", :action => "followable_friends"

  # Partner routes
  # SSS: Some of these paths are hardcoded in JS (application.js and app/views/members/*).
  # If you make changes here, verify that the paths are consistent there
  member_actions = %w(index show new edit my_account login_available invite accept_invitation accepting_invitation update inviting create normal_create).join('|')
  map.connect "partners/:partner_id/:invitation_id/members/:id/:action", :controller => 'members', :requirements => { :id => /./, :action => /#{member_actions}/}
  map.connect "partners/:partner_id/:invitation_id/members/:action", :controller => 'members', :requirements => { :action => /#{member_actions}/}
  map.connect "partners/:partner_id/:invitation_id/members", :controller => 'members'
  map.connect "partners/:partner_id/members", :controller => 'members'
  map.connect "partners/:partner_id", :controller => 'members', :action => 'display_latest_invitation'
  map.connect "partners/:partner_id/:invitation_id", :controller => 'members', :action => 'display_invitation'
  map.connect "partners/:partner_id/:invitation_id/fb_connect/:action", :controller => "facebook_connect", :requirements => { :action => /activate|new_account|link_accounts|link_member|login_and_link|init_activation/ }
  
  # Support for legacy partner routes
  map.connect "signup/:partner_id", :controller => 'members', :action => 'new'

# Comments  - comment out next section if you want to redirect away from comments
  map.connect "/comments", :controller => 'discussions/comments', :action => 'index'
  map.resources :comments, :collection => { :sort => :post }
  map.namespace :discussions do |discussions|
    discussions.resources :comments, :collection => { :sort => :post }, :member => { :undestroy => :post, :reply => :get, :confirm_delete => :get }
  end  
  map.discussions "discussions", :controller => 'discussions/comments', :action => 'index'
  map.site_feedback 'about/site_feedback', :controller => 'discussions/comments', :action => 'show', :id => 1

  # unsubscribe from newsletter
  nl_types = Newsletter::VALID_NEWSLETTER_TYPES + [Newsletter::BULK] + Newsletter::DISABLED_NEWSLETTERS
  nl_types_regexp = /#{nl_types * '|'}/
  map.newsletter_unsubscribe "/newsletter/:freq/unsubscribe/:key",  :controller => "members", :action => "unsubscribe_from_newsletter", :requirements => {:freq => nl_types_regexp}
  map.manage_subscriptions "/subscriptions/",                 :controller => "members", :action => "manage_subscriptions"
  map.manage_subscriptions "/subscriptions/newsletter/",      :controller => "members", :action => "manage_subscriptions"
  map.manage_subscriptions "/subscriptions/email/",           :controller => "members", :action => "manage_subscriptions"
  map.manage_subscription  "/subscriptions/newsletter/:freq", :controller => "members", :action => "manage_subscription", :requirements => { :freq => /#{nl_types * '|'}/ }
  
  # For staff and admins
  map.namespace :admin do |admin|
    # host editing for hostables (topics, subjects, sources) re-using group join/leave tools
    hostable_url_prefix = "members/hosts/:hostable_type/:hostable_id"
    admin.with_options :controller => "members" do |hostables|
      hostables.host_index "#{hostable_url_prefix}.:format", :action => "host_index", :conditions => {:method => :get}
      hostables.host "#{hostable_url_prefix}/join.:format", :action => "host", :conditions => {:method => :post}
      hostables.unhost "#{hostable_url_prefix}/:id/leave.:format", :action => "unhost", :conditions => {:method => :delete}
      hostables.connect "#{hostable_url_prefix}/:id/leave", :action => "unhost", :conditions => {:method => :delete}
    end

    admin.resources :partners do |partners|
      partners.resources :invitations, :member => { :make_primary => :put }
    end
    admin.resources :flags
    admin.resources :members, :collection => { :search => :get, :admin_actions => :get, :spammer_termination_form => :get, :terminate_spammers => :post }
    admin.resources :groups, :collection => { :create_from_template => :get }, :member => {:destroy_image => :delete, :clone_editorial_spaces => :post, :config_group_mynews => :get, :update_group_mynews_settings => :post} do |groups|
      groups.resources :members, :collection => { :join => :post }, :member => { :leave => :delete }
      groups.resources :hosts,   :collection => { :add => :post }
    end
    admin.resources :local_sites do |local_sites|
      local_sites.resources :hosts, :collection => { :add => :post }
    end

    admin.resources :topics,   :member => { :destroy_image => :delete, :layout => :get, :update_layout => :put, :clone_editorial_spaces => :post }, :collection => { :search => :get }
    admin.resources :subjects, :member => { :destroy_image => :delete, :layout => :get, :update_layout => :put, :clone_editorial_spaces => :post }
    admin.resources :sources,  :member => { :destroy_image => :delete }, :collection => { :search => :get, :pending => :get, :hidden => :get, :listed => :get, :featured => :get, :merge_tool => :get, :merge => :post}
    admin.resources :comments, :collection => { :deleted => :get }, :member => { :confirm_delete => :get, :undelete => :get }

    # Stories -- this generated some useless routes for individual stories.  How do I get rid of those?
    admin.resources :stories, :collection => { :index => :get, :merge_tool => :get, :merge_stories => :post, :mass_edit_queued_stories => :get, :mass_update_queued_stories => :put, :autofetch_summary => :get }

    # Feeds
    admin.resources :feeds, :member => { :test => :get, :fetch_now => :get, :edit_stories => :get, :update_stories => :put }

    # Newsletters
    admin.newsletter "newsletter", :controller => "newsletter"

    ## Only the latest newsletter can be acted upon -- hence not using newsletter id!
    nl_types = Newsletter::VALID_NEWSLETTER_TYPES + Newsletter::DISABLED_NEWSLETTERS - [Newsletter::MYNEWS]
    url_prefix = "admin/newsletter/:freq"
    map.with_options :controller => 'admin/newsletter', :requirements => {:freq => /#{nl_types * '|'}/} do |newsletter|
      newsletter.nl_setup           "#{url_prefix}/setup",            :action => "setup"
      newsletter.nl_preview         "#{url_prefix}/preview",          :action => "preview"
      newsletter.nl_refresh_stories "#{url_prefix}/refresh_stories",  :action => "refresh_stories"
      newsletter.nl_reset_template  "#{url_prefix}/reset_template",   :action => "reset_template"
    end

    map.with_options :controller => 'admin/newsletter', :requirements => {:method => :post, :freq => /#{nl_types * '|'}/} do |newsletter|
      newsletter.nl_update              "#{url_prefix}/update",              :action => "update"
      newsletter.nl_submit_for_dispatch "#{url_prefix}/submit_for_dispatch", :action => "submit_for_dispatch"
      newsletter.nl_send_test_mail      "#{url_prefix}/send_test_mail",      :action => "send_test_mail"
      newsletter.nl_send_now            "#{url_prefix}/send_now",            :action => "send_now"
    end

    # Bulk mailer -- with ability to set up templates
    admin.resources :bulk_emails, :collection => { :send_mail => :post, :setup => :get }
    admin.bulk_email_setup "/bulk_emails/setup/:id", :controller => "bulk_emails", :action => "setup", :requirements => {:method => :get}

    # Tags
    admin.tags "/admin/tags", :controller => "tags", :action => "index", :requirements => {:method => :get}
    admin.mass_tag "/admin/tags/mass_tag", :controller => "tags", :action => "mass_tag", :requirements => {:method => :get}
    admin.add_mass_tags "/admin/tags/add_mass_tags", :controller => "tags", :action => "add_mass_tags", :requirements => {:method => :post}

    # home & editorial content
    admin.home 'home/:action', :controller => 'home'
    admin.resources :editorial_spaces
    admin.resources :editorial_blocks, :member => {:preview => :get}

    # templated pages
    admin.pages "pages/index", :controller => "pages", :action => "index"
    admin.edit_page "pages/edit/:page", :controller => "pages", :action => "edit_page"
    admin.update_page "pages/update/:page", :controller => "pages", :action => "update_page", :requirements => {:method => :post}
  end
  map.admin  "admin", :controller => 'admin/dashboard', :action => 'index'

  map.access_denied '/access_denied',:controller => 'home', :action => 'access_denied'

  # Shortcut newsletter management routes (used on legacy system, and still used for simplicity)
  map.connect "/email/", :controller => "members", :action => "manage_subscriptions"
  map.with_options :controller => 'members', :action => "manage_subscription" do |nl_sub|
    nl_sub.email_settings  "/email/:freq",          :requirements => { :freq => nl_types_regexp }
    nl_sub.email_mynews    "/email/mynews",         :freq => "mynews"
    nl_sub.bulk_email      "/email/bulk",           :freq => "special"
    nl_sub.special_notices "/email/special",        :freq => "special"
    nl_sub.connect         "/email/mynews.htm",     :freq => "mynews"
    nl_sub.connect         "/email/daily.htm",      :freq => "daily"
    nl_sub.connect         "/email/weekly.htm",     :freq => "weekly"
    nl_sub.connect         "/email/special",        :freq => "special"
    nl_sub.connect         "/email/notices",        :freq => "special"
    nl_sub.connect         "/email/specialnotices", :freq => "special"
  end

  # Different static/semi-static pages and pages that don't belong anywhere else
  map.with_options :controller => 'pages' do |pages|
    pages.search 'search', :action => 'search'
    pages.scoped_search 'scoped_search/:type', :action => 'scoped_search'
    pages.connect "shorten_url", :action => "shorten_url"

    # subject slug aliases
    pages.connect '/other/*path', :action => 'subject_aliases'
    pages.connect '/subjects/other/*path', :action => 'subject_aliases'

    # other aliases
    pages.connect '/newshunt', :action => "aliases", :from => "newshunt", :to => "newshunts"

    # show of different pages: static/semi-static
    pages.with_options :action => 'show' do |show_page|

      # semi-static pages... just glob
      show_page.page ':section/*path',
        :section => /about|help|tools|partners|rss|widgets|bugs|guides|blog|feedback|donate|schools|teachers|students|mynews_stats|newshunts|groups|local_sites/i

      # handy named route; will get globbed above
      show_page.faq '/help/faq/*path'
      show_page.guides '/guides/*path'
      show_page.donate '/donate/*path'
      show_page.tos '/about/terms'
    end
  end

  # default routes
  map.connect ':controller'
  map.connect ':controller.:format'
  map.connect ':controller/:action'
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
