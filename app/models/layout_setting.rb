class LayoutSetting < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :page, :polymorphic => true
  belongs_to :last_edited_by_member, :foreign_key => "last_edited_by_id", :class_name => "Member"

#  validates_uniqueness_of :name, :scope => [:local_site_id, :page_type, :page_id, :context]

  def unmarshal!
    self.value = ObjectHelpers.unmarshal(self.value)
  end

  def is_true?
    self.value == "1"
  end

  # Find a specific setting with name 'name' in page context 'context' on the landing page obj 'lp_obj'
  def self.find_setting(local_site, lp_obj, context, name)
    LayoutSetting.find(:first, :conditions => {:page_id   => lp_obj ? lp_obj.id : nil,
                                               :page_type => lp_obj ? lp_obj.class.name : nil,
                                               :local_site_id => local_site ? local_site.id : nil,
                                               :context   => context,
                                               :name      => name})
  end

  # Load all settings for page context 'context' on the landing page obj 'lp_obj'
  def self.load_settings(local_site, lp_obj, context)
    settings = find(:all,
                    :conditions => {:context   => context,
                                    :local_site_id => local_site ? local_site.id : nil,
                                    :page_type => lp_obj.nil? ? nil : lp_obj.class.to_s,
                                    :page_id   => lp_obj.nil? ? nil : lp_obj.id},
                    :order => "field_order ASC") 

    # If we didn't get local-site specific settings for a local-site, get a copy of the national-site settings
    if settings.blank? && !local_site.nil?
      settings = find(:all,
                      :conditions => {:context   => context,
                                      :local_site_id => nil,
                                      :page_type => lp_obj.nil? ? nil : lp_obj.class.to_s,
                                      :page_id   => lp_obj.nil? ? nil : lp_obj.id},
                      :order => "field_order ASC")

      # Clear out id & set the local_site attribute for all loaded settings
      settings.each { |s| s.id = nil; s.local_site = local_site }
    end

    # If we didn't find anything in the db, just return preset defaults 
    settings.blank? ? customize_presets(local_site, lp_obj, context.to_s, ObjectHelpers.deep_clone(LAYOUT_DEFAULTS[context.to_sym])) : settings
  end

  # Load all settings for page context 'context' on the landing page obj 'lp_obj' and convert into into a name => value hash
  def self.load_settings_hash(local_site, lp_obj, context)
    load_settings(local_site, lp_obj, context).inject({}) { |h, sc| h[sc.name] = sc; h }
  end

  def self.marshal_hash(h)
    h.each { |k,v| v.strip! if v.class == String }
    val = ObjectHelpers.marshal(h)
    h.keys.each { |k| h.delete(k) }
    h[:value] = val
  end

  private

  def self.init_defaults(hash)
    # SSS: Have to do this so that rake (testing) doesn't choke on these
    begin
      nt_bot_id = Member.nt_bot.id
    rescue
    end

    defaults = {}
    hash.each { |ctxt, ctxt_default|
      defaults[ctxt] = ctxt_default.keys.collect { |k| 
        v = ctxt_default[k] 
        if v
          t = Time.now
          new(:page_id           => nil,
              :page_type         => nil,
              :context           => ctxt,
              :name              => k,
              :value             => v[1],
              :field_order       => v[0],
              :last_edited_by_id => nt_bot_id,
              :created_at        => t,
              :updated_at        => t)
        end
      }.compact.sort { |l1, l2| l1.field_order <=> l2.field_order }
    }
    defaults
  end

  # Customize layout defaults as necessary to make it suitable for the landing page it is going to be used on.
  def self.customize_presets(local_site, lp_obj, context, layout_defaults)
    layout_defaults ||= []
    if context == "news_comparison" 
      if [Topic,Subject].include?(lp_obj.class)
        layout_defaults.find { |ls| ls.name == "topic" }.value = lp_obj.slug
      elsif !local_site.nil?
        layout_defaults.find { |ls| ls.name == "topic" }.value = Topic.for_site(local_site).find_by_tag_id(local_site.constraint_id).slug
      end
    elsif context == "staging" && !local_site.nil?
      layout_defaults.find { |ls| ls.name == "topic" }.value = Topic.for_site(local_site).find_by_tag_id(local_site.constraint_id).slug
    end

    # Initialize local site value!
    layout_defaults.each { |s| s.local_site = local_site; s.page = lp_obj }

    return layout_defaults
  end

  LAYOUT_DEFAULTS = init_defaults({
    :staging => {
      "featured_topic"       => [1, ""],
      "review_1"             => [2, ""],
      "review_2"             => [3, ""],
      "block_1"              => [4, ""],
      "block_2"              => [5, ""],
    },
    :featured_story => {
      "show_box?"            => [1, "0"],
      "box_title"            => [2, "Featured Story"],
      "story_label"          => [3, ""], # SSS: Is this still needed?
      "story"                => [4, ""],
      "use_topic_photo?"     => [5, "0"],
      "story_call_to_action" => [6, ""],
      "review_1"             => [7, ""],
      "review_2"             => [8, ""],
      "block_1"              => [9, ""],
      "block_2"              => [10, ""],
    },
    :news_comparison => {
      "show_box?"                 => [1, "0"],
      "heading"                   => [2, "News Comparison"],
      "subtopic"                  => [3, ""],
      "topic_description"         => [4, "Compare these stories"],
      "topic"                     => [5, ""],
      "use_topic_listing?"        => [6, "1"],
      "topic_listing"             => [7, marshal_hash({"source_ownership"=>"", "story_type"=>"", "listing_type"=>"most_recent"})],
      "story_1"                   => [8, ""],
      "story_2"                   => [9, ""],
      "story_3"                   => [10, ""],
      "link_stories?"             => [11, "0"],
      "compare_more_stories_link" => [12, ""],
    },
    :grid => {
      "show_box?"  => [1, "1"],
      "box_title"  => [2, "Top Stories"],
      "show_row1?" => [3, "1"],
      "row1_label" => [4, ""],
      "c1"         => [5, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>Source::MSM, "story_type"=>Story::NEWS, "listing_type"=>"most_recent"}, "lt_slug"=>"", "label"=>"NEWS - Mainstream Media"})],
      "c2"         => [6, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>Source::IND, "story_type"=>Story::NEWS, "listing_type"=>"most_recent"}, "lt_slug"=>"", "label"=>"NEWS - Independent Media"})],
      "c3"         => [7, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>"", "story_type"=>Story::OPINION, "listing_type"=>"most_recent"}, "lt_slug"=>"", "label"=>"OPINION - All Media"})],
      "show_row2?" => [8, "0"],
      "row2_label" => [9, ""],
      "c4"         => [10, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>Source::MSM, "story_type"=>Story::NEWS, "listing_type"=>"most_trusted"}, "lt_slug"=>"", "label"=>"NEWS - Most Trusted (MSM)"})],
      "c5"         => [11, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>Source::IND, "story_type"=>Story::NEWS, "listing_type"=>"most_trusted"}, "lt_slug"=>"", "label"=>"NEWS - Most Trusted (IND)"})],
      "c6"         => [12, marshal_hash({"story"=>"", "listing"=>{"source_ownership"=>"", "story_type"=>Story::OPINION, "listing_type"=>"most_trusted"}, "lt_slug"=>"", "label"=>"OPINION - Most Trusted"})],
    },
    :right_column => {
      "show_photo?"        => [1, "1"],
      "show_top_sources?"  => [2, "1"],
      "show_widget?"       => [3, "1"],
      "show_other_topics?" => [4, "1"]
    }
  })
end
