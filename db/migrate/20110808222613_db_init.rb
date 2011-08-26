class DbInit < ActiveRecord::Migration
  def self.up
# This file was auto-generated from the last state of the database.

ActiveRecord::Schema.define do
  create_table "activity_entries", :force => true do |t|
    t.integer  "member_id"
    t.string   "activity_type"
    t.integer  "activity_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "referrer_code", :limit => 11
  end

  add_index "activity_entries", ["member_id", "activity_type"], :name => "index_activity_entries_on_member_id_and_activity_type"
  add_index "activity_entries", ["updated_at", "member_id"], :name => "index_activity_entries_on_updated_at_and_member_id"

  create_table "affiliations", :force => true do |t|
    t.integer  "member_id",  :limit => 8
    t.integer  "source_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "aggregate_statistics", :force => true do |t|
    t.string   "model_type"
    t.integer  "model_id"
    t.string   "statistic"
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "arg"
  end

  add_index "aggregate_statistics", ["model_type", "model_id", "statistic"], :name => "model_and_statistic_index"

  create_table "authorships", :force => true do |t|
    t.integer  "story_id",   :limit => 8
    t.integer  "source_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "authorships", ["source_id"], :name => "index_authorships_on_source_id"
  add_index "authorships", ["story_id", "source_id"], :name => "index_authorships_on_story_id_and_source_id", :unique => true

  create_table "auto_fetched_stories", :force => true do |t|
    t.integer  "story_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "body",        :limit => 16777215
    t.text     "description"
    t.boolean  "fresh_story",                     :default => false
  end

  add_index "auto_fetched_stories", ["story_id"], :name => "index_auto_fetched_stories_on_story_id"

  create_table "bj_config", :primary_key => "bj_config_id", :force => true do |t|
    t.text "hostname"
    t.text "key"
    t.text "value"
    t.text "cast"
  end

  create_table "bj_job", :primary_key => "bj_job_id", :force => true do |t|
    t.text     "command"
    t.text     "state"
    t.integer  "priority",       :limit => 8
    t.text     "tag"
    t.integer  "is_restartable", :limit => 8
    t.text     "submitter"
    t.text     "runner"
    t.integer  "pid",            :limit => 8
    t.datetime "submitted_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text     "env"
    t.text     "stdin"
    t.text     "stdout"
    t.text     "stderr"
    t.integer  "exit_status",    :limit => 8
  end

  create_table "bj_job_archive", :primary_key => "bj_job_archive_id", :force => true do |t|
    t.text     "command"
    t.text     "state"
    t.integer  "priority",       :limit => 8
    t.text     "tag"
    t.integer  "is_restartable", :limit => 8
    t.text     "submitter"
    t.text     "runner"
    t.integer  "pid",            :limit => 8
    t.datetime "submitted_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "archived_at"
    t.text     "env"
    t.text     "stdin"
    t.text     "stdout"
    t.text     "stderr"
    t.integer  "exit_status",    :limit => 8
  end

  create_table "bulk_emails", :force => true do |t|
    t.string   "template_name"
    t.boolean  "is_reinvite"
    t.string   "invitation_code"
    t.string   "from"
    t.text     "to"
    t.text     "subject"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "html_mail",            :default => false
    t.text     "html_body"
    t.boolean  "ignore_no_bulk_email", :default => false
    t.integer  "local_site_id"
  end

  create_table "comments", :force => true do |t|
    t.integer  "member_id",             :limit => 8
    t.integer  "parent_id",             :limit => 8
    t.integer  "lft",                   :limit => 8
    t.integer  "rgt",                   :limit => 8
    t.string   "title"
    t.boolean  "hidden",                             :default => false
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "last_edited_by_id",     :limit => 8
    t.integer  "commentable_id"
    t.string   "commentable_type"
    t.boolean  "hidden_through_muzzle",              :default => false
  end

  add_index "comments", ["commentable_id", "commentable_type"], :name => "index_comments_on_commentable_id_and_commentable_type"
  add_index "comments", ["hidden_through_muzzle"], :name => "index_comments_on_hidden_through_muzzle"

  create_table "editorial_block_assignments", :force => true do |t|
    t.integer  "editorial_block_id"
    t.integer  "editorial_space_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "editorial_blocks", :force => true do |t|
    t.text     "body"
    t.string   "slug"
    t.string   "context"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "editorial_spaces", :force => true do |t|
    t.string   "name"
    t.string   "context"
    t.integer  "position",      :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "show_name",                  :default => true
    t.string   "page_type"
    t.integer  "page_id"
    t.integer  "local_site_id"
    t.string   "eb_arg"
  end

  add_index "editorial_spaces", ["local_site_id", "page_id", "page_type"], :name => "editorial_spaces_index"

  create_table "excerpts", :force => true do |t|
    t.integer  "review_id",  :limit => 8
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
  end

  add_index "excerpts", ["review_id"], :name => "index_excerpts_on_review_id"

  create_table "facebook_connect_settings", :force => true do |t|
    t.integer  "member_id"
    t.string   "fb_uid",              :limit => 40
    t.boolean  "autofollow_friends",                :default => false
    t.boolean  "ep_read_stream",                    :default => false
    t.boolean  "ep_publish_stream",                 :default => false
    t.boolean  "ep_offline_access",                 :default => false
    t.text     "offline_session_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "friendships_cached",                :default => false
  end

  add_index "facebook_connect_settings", ["member_id"], :name => "index_facebook_connect_settings_on_member_id"

  create_table "facebook_invitations", :force => true do |t|
    t.integer  "member_id"
    t.string   "fb_uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "favorites", :force => true do |t|
    t.integer  "member_id",        :limit => 8
    t.integer  "favoritable_id",   :limit => 8
    t.string   "favoritable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "feeds", :force => true do |t|
    t.text     "url"
    t.integer  "source_id",         :limit => 8
    t.boolean  "auto_fetch",                      :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "success_count",     :limit => 8
    t.integer  "failure_count",     :limit => 8
    t.string   "name"
    t.string   "description"
    t.string   "home_page"
    t.integer  "feed_level"
    t.datetime "last_fetched_at"
    t.integer  "last_fetched_by"
    t.text     "default_topics"
    t.string   "default_stype"
    t.text     "subtitle"
    t.string   "feed_type",         :limit => 32
    t.string   "feed_group"
    t.integer  "source_profile_id", :limit => 8
    t.integer  "member_profile_id", :limit => 8
    t.text     "imported_desc"
    t.text     "edit_notes"
  end

  create_table "flags", :force => true do |t|
    t.integer  "user_id"
    t.integer  "flaggable_id"
    t.string   "flaggable_type"
    t.integer  "flaggable_user_id"
    t.string   "reason"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "flags", ["flaggable_id"], :name => "index_flags_on_flaggable_id"
  add_index "flags", ["flaggable_type"], :name => "index_flags_on_flaggable_type"
  add_index "flags", ["flaggable_user_id"], :name => "index_flags_on_flaggable_user_id"
  add_index "flags", ["reason"], :name => "index_flags_on_reason"
  add_index "flags", ["user_id"], :name => "index_flags_on_user_id"

  create_table "followed_items", :force => true do |t|
    t.integer  "follower_id"
    t.integer  "followable_id"
    t.string   "followable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "followed_items", ["follower_id", "followable_id", "followable_type"], :name => "unique_followed_items_index", :unique => true

  create_table "group_stories", :force => true do |t|
    t.integer  "group_id"
    t.integer  "story_id"
    t.integer  "reviews_count"
    t.float    "rating"
    t.float    "sort_rating"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "group_stories", ["group_id", "story_id", "sort_rating"], :name => "index_group_stories_on_group_id_and_story_id_and_sort_rating", :unique => true

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "memberships_count", :limit => 8, :default => 0
    t.string   "context"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_protected",                   :default => false
    t.string   "slug"
  end

  add_index "groups", ["slug"], :name => "index_groups_on_slug", :unique => true

  create_table "hostings", :force => true do |t|
    t.integer  "member_id",     :limit => 8
    t.integer  "hostable_id",   :limit => 8
    t.string   "hostable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "page_host_id"
  end

  create_table "images", :force => true do |t|
    t.integer  "imageable_id",   :limit => 8
    t.string   "imageable_type"
    t.integer  "parent_id",      :limit => 8
    t.string   "content_type"
    t.string   "filename"
    t.string   "thumbnail"
    t.integer  "size",           :limit => 8
    t.integer  "width",          :limit => 8
    t.integer  "height",         :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "credit"
    t.string   "credit_url"
  end

  add_index "images", ["imageable_id", "imageable_type"], :name => "index_images_on_imageable_id_and_imageable_type"

  create_table "invitations", :force => true do |t|
    t.integer  "validation_level",         :limit => 8
    t.integer  "partner_id",               :limit => 8
    t.string   "name"
    t.text     "landing_page_template"
    t.text     "invite_message"
    t.text     "welcome_page_template"
    t.text     "additional_signup_fields"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email_subject"
    t.string   "email_from"
    t.string   "code"
    t.text     "success_page_template"
    t.string   "landing_page_link"
    t.string   "welcome_page_link"
    t.string   "success_page_link"
    t.string   "widget_newshunt_topic"
    t.string   "widget_newshunt_url"
    t.string   "widget_newshunt_title"
    t.text     "widget_newshunt_desc"
    t.integer  "group_id"
  end

  create_table "layout_settings", :force => true do |t|
    t.string   "name"
    t.string   "value",             :limit => 2048
    t.integer  "last_edited_by_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "context"
    t.integer  "field_order",                       :default => 100
    t.string   "page_type"
    t.integer  "page_id"
    t.integer  "local_site_id"
  end

  add_index "layout_settings", ["local_site_id", "page_id", "page_type"], :name => "index_layout_settings_on_local_site_id_and_page_id_and_page_type"

  create_table "local_sites", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.integer  "invitation_id"
    t.string   "constraint_type"
    t.string   "constraint_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "subdomain",              :default => ""
    t.string   "subject_slugs",          :default => "us, politics, business, scitech"
    t.boolean  "is_active",              :default => true
    t.string   "navbar_background_css"
    t.boolean  "has_daily_newsletter",   :default => false
    t.boolean  "has_weekly_newsletter",  :default => false
    t.integer  "max_stories_per_source", :default => 3
    t.string   "invitation_code"
  end

  add_index "local_sites", ["slug"], :name => "index_local_sites_on_slug"

  create_table "local_sites_sources", :id => false, :force => true do |t|
    t.integer  "local_site_id"
    t.integer  "source_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "member_attributes", :force => true do |t|
    t.integer  "member_id",  :limit => 8,                   :null => false
    t.string   "name",                    :default => "",   :null => false
    t.boolean  "visible",                 :default => true
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "member_attributes", ["member_id"], :name => "index_member_attributes_on_member_id"

  create_table "member_donations", :force => true do |t|
    t.integer  "member_id",             :limit => 8,                                :null => false
    t.integer  "donation_count",        :limit => 8
    t.decimal  "donation_amount",                    :precision => 12, :scale => 2
    t.string   "donation_info"
    t.decimal  "donation_total_amount",              :precision => 12, :scale => 2
    t.datetime "donation_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "members", :force => true do |t|
    t.integer  "validation_level",               :limit => 8,  :default => 1
    t.string   "legacy_id"
    t.string   "openid_url"
    t.string   "name"
    t.string   "email"
    t.string   "crypted_password"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "login"
    t.datetime "remember_token_expires_at"
    t.string   "remember_token"
    t.boolean  "show_email",                                   :default => false
    t.boolean  "show_in_member_list",                          :default => true
    t.string   "show_profile",                   :limit => 8,  :default => "public"
    t.boolean  "valid_email",                                  :default => true
    t.string   "profile_status",                               :default => "list"
    t.integer  "priority",                       :limit => 8,  :default => 3
    t.integer  "total_reviews",                  :limit => 8,  :default => 0
    t.integer  "total_answers",                  :limit => 8,  :default => 0
    t.integer  "total_meta_reviews_received",    :limit => 8,  :default => 0
    t.integer  "total_meta_reviewers",           :limit => 8,  :default => 0
    t.integer  "total_meta_reviews_given",       :limit => 8,  :default => 0
    t.string   "status",                                       :default => "guest"
    t.string   "newsletter_format",                            :default => "html"
    t.datetime "last_edited_at"
    t.integer  "news_experience",                :limit => 8
    t.boolean  "show_news_experience",                         :default => true
    t.integer  "internet_experience",            :limit => 8
    t.boolean  "show_internet_experience",                     :default => true
    t.integer  "education_experience",           :limit => 8
    t.boolean  "show_education_experience",                    :default => true
    t.integer  "journalism_experience",          :limit => 8
    t.boolean  "show_journalism_experience",                   :default => true
    t.integer  "edited_by_member_id",            :limit => 8
    t.integer  "validated_by_member_id",         :limit => 8
    t.string   "activation_code",                :limit => 40
    t.datetime "activated_at"
    t.integer  "referred_by",                    :limit => 8
    t.float    "rating"
    t.string   "pseudonym"
    t.boolean  "show_affiliations",                            :default => true
    t.boolean  "show_favorites",                               :default => true
    t.string   "preferred_review_form_version"
    t.datetime "last_validated_at"
    t.datetime "last_active_at"
    t.boolean  "password_reset",                               :default => false
    t.string   "email_hash",                     :limit => 51
    t.boolean  "show_fb_profile_url",                          :default => true
    t.text     "email_notification_preferences"
    t.integer  "total_meta_comments",                          :default => 0
    t.boolean  "muzzled",                                      :default => false
    t.boolean  "bulk_email",                                   :default => true
    t.string   "preferred_edit_form_version",                  :default => "short"
  end

  add_index "members", ["email"], :name => "index_members_on_email", :unique => true
  add_index "members", ["email_hash"], :name => "index_members_on_email_hash"
  add_index "members", ["legacy_id"], :name => "index_members_on_legacy_id", :unique => true
  add_index "members", ["name"], :name => "index_members_on_name", :unique => true
  add_index "members", ["rating"], :name => "index_members_on_rating"
  add_index "members", ["total_meta_comments"], :name => "index_members_on_total_meta_comments"

  create_table "memberships", :force => true do |t|
    t.integer  "member_id",           :limit => 8
    t.boolean  "public",                           :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "membershipable_id",   :limit => 8
    t.string   "membershipable_type"
    t.integer  "invitation_id",       :limit => 8
  end

  add_index "memberships", ["membershipable_type", "membershipable_id", "member_id"], :name => "memberships_unique_index", :unique => true

  create_table "meta_reviews", :force => true do |t|
    t.integer  "member_id",  :limit => 8,                     :null => false
    t.integer  "review_id",  :limit => 8,                     :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "rating"
    t.string   "status",                  :default => "list"
  end

  add_index "meta_reviews", ["member_id"], :name => "index_meta_reviews_on_member_id"
  add_index "meta_reviews", ["review_id"], :name => "index_meta_reviews_on_review_id"

  create_table "newsletter_recipients", :force => true do |t|
    t.integer  "newsletter_id", :limit => 8
    t.integer  "member_id",     :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "newsletter_recipients", ["newsletter_id", "member_id"], :name => "index_newsletter_recipients_on_newsletter_id_and_member_id"

  create_table "newsletter_stories", :force => true do |t|
    t.integer "story_id",      :limit => 8
    t.integer "newsletter_id", :limit => 8
    t.string  "listing_type",  :limit => 32
  end

  add_index "newsletter_stories", ["newsletter_id", "story_id"], :name => "index_newsletter_stories_on_newsletter_id_and_story_id"
  add_index "newsletter_stories", ["story_id"], :name => "fk_newsletter_stories_1"

  create_table "newsletter_subscriptions", :force => true do |t|
    t.integer  "member_id"
    t.string   "newsletter_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "newsletter_subscriptions", ["member_id", "newsletter_type"], :name => "index_newsletter_subscriptions_on_member_id_and_newsletter_type", :unique => true

  create_table "newsletters", :force => true do |t|
    t.string   "freq"
    t.string   "state"
    t.text     "text_header"
    t.text     "text_footer"
    t.text     "html_header"
    t.text     "html_footer"
    t.text     "subject"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "dispatch_time"
    t.boolean  "add_top_story_title_to_subject"
    t.integer  "bj_job_id",                      :limit => 8
    t.datetime "refreshed_at"
  end

  create_table "open_id_authentication_associations", :force => true do |t|
    t.integer "issued",     :limit => 8
    t.integer "lifetime",   :limit => 8
    t.string  "handle"
    t.string  "assoc_type"
    t.binary  "server_url"
    t.binary  "secret"
  end

  create_table "open_id_authentication_nonces", :force => true do |t|
    t.integer "timestamp",  :limit => 8,                 :null => false
    t.string  "server_url",              :default => "", :null => false
    t.string  "salt",                    :default => "", :null => false
  end

  create_table "openid_profiles", :force => true do |t|
    t.string   "openid_url",              :default => "", :null => false
    t.integer  "member_id",  :limit => 8,                 :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "page_hosts", :force => true do |t|
    t.integer  "member_id"
    t.integer  "local_site_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "page_hosts", ["member_id", "local_site_id"], :name => "index_page_hosts_on_member_id_and_local_site_id"

  create_table "page_views", :force => true do |t|
    t.string   "session_id"
    t.integer  "viewable_id",   :limit => 8
    t.string   "viewable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "page_views", ["viewable_id", "viewable_type", "session_id"], :name => "index_page_views_on_viewable_id_type_and_session_id", :unique => true

  create_table "partners", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.integer  "memberships_count", :limit => 8, :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "primary_invite_id"
  end

  create_table "pending_notifications", :force => true do |t|
    t.integer  "member_id"
    t.string   "trigger_obj_type"
    t.integer  "trigger_obj_id"
    t.string   "notification_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "local_site_id"
  end

  create_table "persistent_key_value_pairs", :force => true do |t|
    t.string   "key"
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "process_jobs", :force => true do |t|
    t.integer  "processable_id",   :limit => 8
    t.string   "processable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
    t.string   "processor_method"
  end

  create_table "processed_rating_versions", :force => true do |t|
    t.integer  "processable_id",   :limit => 8
    t.string   "processable_type"
    t.string   "rating_type"
    t.float    "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "processed_rating_versions", ["processable_id", "processable_type"], :name => "index_processed_rating_versions_on_processable_id_and_type"

  create_table "processed_ratings", :force => true do |t|
    t.integer  "processable_id",   :limit => 8
    t.string   "processable_type",              :default => "", :null => false
    t.string   "rating_type"
    t.float    "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
  end

  add_index "processed_ratings", ["processable_id", "processable_type", "group_id"], :name => "processed_ratings_index"

  create_table "ratings", :force => true do |t|
    t.integer "ratable_id",   :limit => 8
    t.string  "ratable_type",              :default => "", :null => false
    t.string  "criterion"
    t.integer "value",        :limit => 8,                 :null => false
  end

  add_index "ratings", ["ratable_id", "ratable_type"], :name => "index_ratings_on_ratable_id_and_ratable_type"

  create_table "reviews", :force => true do |t|
    t.integer  "member_id"
    t.integer  "story_id",         :limit => 8,                     :null => false
    t.string   "legacy_id"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "rating"
    t.string   "status",                        :default => "list"
    t.string   "form_version"
    t.string   "disclosure"
    t.text     "personal_comment"
  end

  add_index "reviews", ["created_at", "member_id"], :name => "index_reviews_on_created_at_and_member_id"
  add_index "reviews", ["member_id", "story_id"], :name => "index_reviews_on_member_id_and_story_id", :unique => true
  add_index "reviews", ["story_id", "created_at"], :name => "index_reviews_on_story_id_and_created_at"

  create_table "saves", :force => true do |t|
    t.integer  "member_id",  :limit => 8
    t.integer  "story_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "saves", ["member_id", "story_id"], :name => "index_saves_on_member_id_and_story_id"
  add_index "saves", ["story_id"], :name => "index_saves_on_story_id"

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :default => "", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "sharables", :force => true do |t|
    t.integer  "member_id",       :limit => 8
    t.integer  "sharable_id",     :limit => 8
    t.string   "sharable_type",   :limit => 12
    t.string   "sharable_target", :limit => 2
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sharables", ["sharable_id", "sharable_type", "sharable_target"], :name => "sharables_unique_index", :unique => true

  create_table "short_urls", :force => true do |t|
    t.string   "page_type"
    t.integer  "page_id"
    t.string   "url_type"
    t.integer  "local_site_id"
    t.string   "short_url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "short_urls", ["page_type", "page_id", "url_type", "local_site_id"], :name => "short_urls_unique_index", :unique => true

  create_table "slugs", :force => true do |t|
    t.string   "name"
    t.string   "sluggable_type"
    t.integer  "sluggable_id",   :limit => 8
    t.datetime "created_at"
    t.integer  "sequence",                     :default => 1, :null => false
    t.string   "scope",          :limit => 40
  end

  add_index "slugs", ["name", "sluggable_type", "scope", "sequence"], :name => "index_slugs_on_n_s_s_and_s", :unique => true
  add_index "slugs", ["sluggable_id"], :name => "index_slugs_on_sluggable_id"

  create_table "social_group_attributes", :force => true do |t|
    t.integer  "group_id"
    t.integer  "mynews_dummy_member_id"
    t.boolean  "activated",                :default => false
    t.date     "activation_date"
    t.integer  "num_init_story_days",      :default => 0
    t.string   "subtitle"
    t.string   "group_info_title",         :default => "Group Info"
    t.string   "short_name"
    t.string   "email"
    t.string   "invitation_code"
    t.string   "status",                   :default => "hide"
    t.string   "category",                 :default => "social"
    t.string   "moderation",               :default => "none"
    t.string   "visibility",               :default => "nt"
    t.string   "membership_mode",          :default => "open"
    t.string   "listing_mode",             :default => "members"
    t.string   "listings",                 :default => ""
    t.boolean  "allow_comments",           :default => false
    t.text     "discussion_description"
    t.text     "host_notes"
    t.integer  "num_msm_stories"
    t.integer  "num_ind_stories"
    t.integer  "listing_date_window_size", :default => 60
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "website_url"
    t.string   "default_listing"
    t.string   "tag_id_list"
  end

  create_table "social_network_friendships", :force => true do |t|
    t.string   "network_code", :limit => 2
    t.integer  "member_id"
    t.string   "friend_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "social_network_friendships", ["network_code", "member_id", "friend_id"], :name => "snf_network_member_friend"

  create_table "source_attributes", :force => true do |t|
    t.integer  "source_id",  :limit => 8,                 :null => false
    t.string   "name",                    :default => "", :null => false
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "source_attributes", ["source_id"], :name => "index_source_attributes_on_source_id"

  create_table "source_media", :force => true do |t|
    t.integer  "source_id",  :limit => 8
    t.string   "medium"
    t.boolean  "main"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "source_media", ["source_id", "medium"], :name => "index_source_media_on_source_id_and_medium"

  create_table "source_relations", :force => true do |t|
    t.integer  "source_id",         :limit => 8
    t.integer  "related_source_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "source_relations", ["source_id"], :name => "index_source_relations_on_source_id"

  create_table "source_reviews", :force => true do |t|
    t.integer  "source_id",           :limit => 8
    t.integer  "member_id",           :limit => 8
    t.float    "rating"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                           :default => "list"
    t.text     "note"
    t.text     "expertise_topic_ids"
    t.integer  "local_site_id"
  end

  add_index "source_reviews", ["local_site_id", "source_id", "member_id"], :name => "source_reviews_unique_index", :unique => true

  create_table "source_stats", :force => true do |t|
    t.integer  "source_id"
    t.integer  "local_site_id"
    t.float    "rating",                 :default => 0.0
    t.float    "review_rating",          :default => 0.0
    t.integer  "authorships_count",      :default => 0
    t.integer  "story_reviews_count",    :default => 0
    t.integer  "reviewed_stories_count", :default => 0
    t.integer  "source_reviews_count",   :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "source_stats", ["source_id", "local_site_id"], :name => "index_source_stats_on_source_id_and_local_site_id"

  create_table "sources", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "domain"
    t.string   "ownership"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "section"
    t.datetime "last_edited_at"
    t.integer  "edited_by_member_id",    :limit => 8
    t.float    "rating"
    t.string   "status",                              :default => "list"
    t.string   "url"
    t.integer  "authorships_count",      :limit => 8, :default => 0
    t.integer  "source_reviews_count",   :limit => 8, :default => 0
    t.integer  "story_reviews_count",    :limit => 8, :default => 0
    t.integer  "reviewed_stories_count",              :default => 0
    t.text     "discussion_description"
    t.boolean  "allow_comments",                      :default => false
    t.boolean  "is_framebuster",                      :default => false
    t.integer  "editorial_priority",                  :default => 1
    t.float    "review_rating",                       :default => 0.0
  end

  add_index "sources", ["slug"], :name => "index_sources_on_slug"
  add_index "sources", ["domain", "section"], :name => "index_sources_on_domain_and_section"
  add_index "sources", ["rating", "status"], :name => "index_sources_on_rating_and_status"

  create_table "spammer_ips", :force => true do |t|
    t.string   "ip"
    t.integer  "spammer_count"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stories", :force => true do |t|
    t.integer  "submitted_by_id",        :limit => 8
    t.string   "legacy_id"
    t.string   "title"
    t.string   "url"
    t.string   "story_type"
    t.datetime "story_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "tag_aggregate"
    t.text     "subtitle"
    t.text     "excerpt"
    t.string   "journalist_names"
    t.string   "status",                              :default => "list"
    t.integer  "editorial_priority",     :limit => 8
    t.integer  "edited_by_member_id",    :limit => 8
    t.datetime "last_edited_at"
    t.float    "rating"
    t.integer  "reviews_count",          :limit => 8, :default => 0
    t.integer  "stype_code",             :limit => 8, :default => 0
    t.integer  "primary_source_id",      :limit => 8
    t.string   "primary_source_medium"
    t.integer  "saves_count",            :limit => 8, :default => 0
    t.integer  "page_views_count",       :limit => 8, :default => 0
    t.date     "sort_date"
    t.integer  "emails_count",           :limit => 8, :default => 0
    t.float    "sort_rating",                         :default => 0.0
    t.string   "content_type"
    t.text     "discussion_description"
    t.boolean  "edit_lock",                           :default => false
    t.integer  "activity_score",                      :default => 1000
    t.boolean  "is_local"
    t.float    "autolist_score"
  end

  add_index "stories", ["activity_score", "sort_date", "sort_rating"], :name => "index_stories_on_activity_score_and_sort_date_and_sort_rating"
  add_index "stories", ["legacy_id"], :name => "index_stories_on_legacy_id", :unique => true
  add_index "stories", ["sort_date", "autolist_score"], :name => "index_stories_on_sort_date_and_autolist_score"
  add_index "stories", ["sort_date", "sort_rating"], :name => "index_stories_on_sort_date_and_sort_rating"
  add_index "stories", ["stype_code", "sort_date", "sort_rating"], :name => "index_stories_on_stype_code_and_sort_date_and_sort_rating"
  add_index "stories", ["submitted_by_id", "created_at"], :name => "index_stories_on_submitted_by_id_and_created_at"
  add_index "stories", ["url"], :name => "index_stories_on_url"

  create_table "story_attributes", :force => true do |t|
    t.integer  "story_id",   :limit => 8,                 :null => false
    t.string   "name",                    :default => "", :null => false
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "story_attributes", ["story_id"], :name => "index_story_attributes_on_story_id"

  create_table "story_clicks", :force => true do |t|
    t.integer  "story_id",   :limit => 8
    t.string   "data",       :limit => 32
    t.datetime "created_at"
  end

  add_index "story_clicks", ["story_id", "data"], :name => "index_story_clicks_on_story_id_and_data", :unique => true

  create_table "story_feeds", :force => true do |t|
    t.integer "story_id", :limit => 8
    t.integer "feed_id",  :limit => 8
  end

  add_index "story_feeds", ["story_id", "feed_id"], :name => "index_story_feeds_on_story_id_and_feed_id"

  create_table "story_relations", :force => true do |t|
    t.integer  "story_id",         :limit => 8
    t.integer  "related_story_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "member_id",        :limit => 8
  end

  add_index "story_relations", ["related_story_id"], :name => "index_story_relations_on_related_story_id"
  add_index "story_relations", ["story_id"], :name => "index_story_relations_on_story_id"

  create_table "story_urls", :force => true do |t|
    t.string   "url"
    t.integer  "story_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "story_urls", ["story_id"], :name => "index_story_urls_on_story_id"
  add_index "story_urls", ["url"], :name => "index_story_urls_on_url"

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id",        :limit => 8
    t.integer  "taggable_id",   :limit => 8
    t.integer  "member_id",     :limit => 8
    t.string   "taggable_type"
    t.string   "context"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "member_id"], :name => "tagging_unique_index", :unique => true
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string  "name"
    t.integer "taggings_count", :limit => 8, :default => 0
    t.string  "slug"
    t.string  "tag_type"
  end

  add_index "tags", ["name"], :name => "index_tags_on_name", :unique => true
  add_index "tags", ["slug"], :name => "index_tags_on_slug", :unique => true

  create_table "topic_relations", :force => true do |t|
    t.integer  "topic_id",         :limit => 8
    t.integer  "related_topic_id", :limit => 8
    t.string   "context"
    t.string   "grouping"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "local_site_id"
  end

  add_index "topic_relations", ["topic_id"], :name => "index_tag_relations_on_tag_id"

  create_table "topics", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "local_site_id"
    t.string   "slug"
    t.string   "name"
    t.integer  "parent_topic_id"
    t.string   "type"
    t.text     "intro"
    t.integer  "topic_volume",           :limit => 8, :default => 60
    t.string   "status",                              :default => "list"
    t.integer  "num_msm_stories",        :limit => 8, :default => 3
    t.integer  "num_ind_stories",        :limit => 8, :default => 2
    t.text     "discussion_description"
    t.boolean  "allow_comments",                      :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "topics", ["tag_id", "local_site_id"], :name => "index_topics_on_tag_id_and_local_site_id", :unique => true

  create_table "twitter_settings", :force => true do |t|
    t.integer  "member_id",          :limit => 8
    t.integer  "tw_id",              :limit => 8
    t.string   "tw_uid",             :limit => 32
    t.text     "access_token"
    t.text     "secret_token"
    t.boolean  "can_read",                         :default => false
    t.boolean  "can_post",                         :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "friendships_cached",               :default => false
  end

  add_index "twitter_settings", ["member_id"], :name => "index_twitter_settings_on_member_id"

  create_table "videos", :force => true do |t|
    t.text     "embed_code"
    t.integer  "story_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end
  end

  def self.down
    drop_table "activity_entries"
    drop_table "affiliations"
    drop_table "aggregate_statistics"
    drop_table "authorships"
    drop_table "auto_fetched_stories"
    drop_table "bj_config"
    drop_table "bj_job"
    drop_table "bj_job_archive"
    drop_table "bulk_emails"
    drop_table "comments"
    drop_table "editorial_block_assignments"
    drop_table "editorial_blocks"
    drop_table "editorial_spaces"
    drop_table "excerpts"
    drop_table "facebook_connect_settings"
    drop_table "facebook_invitations"
    drop_table "favorites"
    drop_table "feeds"
    drop_table "flags"
    drop_table "followed_items"
    drop_table "group_stories"
    drop_table "groups"
    drop_table "hostings"
    drop_table "images"
    drop_table "invitations"
    drop_table "layout_settings"
    drop_table "local_sites"
    drop_table "local_sites_sources"
    drop_table "member_attributes"
    drop_table "member_donations"
    drop_table "members"
    drop_table "memberships"
    drop_table "meta_reviews"
    drop_table "newsletter_recipients"
    drop_table "newsletter_stories"
    drop_table "newsletter_subscriptions"
    drop_table "newsletters"
    drop_table "open_id_authentication_associations"
    drop_table "open_id_authentication_nonces"
    drop_table "openid_profiles"
    drop_table "page_hosts"
    drop_table "page_views"
    drop_table "partners"
    drop_table "pending_notifications"
    drop_table "persistent_key_value_pairs"
    drop_table "process_jobs"
    drop_table "processed_rating_versions"
    drop_table "processed_ratings"
    drop_table "ratings"
    drop_table "reviews"
    drop_table "saves"
    drop_table "sessions"
    drop_table "sharables"
    drop_table "short_urls"
    drop_table "slugs"
    drop_table "social_group_attributes"
    drop_table "social_network_friendships"
    drop_table "source_attributes"
    drop_table "source_media"
    drop_table "source_relations"
    drop_table "source_reviews"
    drop_table "source_stats"
    drop_table "sources"
    drop_table "spammer_ips"
    drop_table "stories"
    drop_table "story_attributes"
    drop_table "story_clicks"
    drop_table "story_feeds"
    drop_table "story_relations"
    drop_table "story_urls"
    drop_table "taggings"
    drop_table "tags"
    drop_table "topic_relations"
    drop_table "topics"
    drop_table "twitter_settings"
    drop_table "videos"
  end
end
