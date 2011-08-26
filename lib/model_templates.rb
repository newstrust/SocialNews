module ModelTemplates
  def self.init_group
    g_defs = {
      :name         => "Group: #{Time.now}",
      :description  => "<p>This is the news group for [NAME OF GROUP].</p>" + \
                       "<p>Please <a href='/members/new'>sign up for #{SocialNewsConfig["app"]["name"]} here</a>, if you are not yet a member.</p>",
      :context      => Group::GroupType::SOCIAL,
      :is_protected => true,
      :slug         => "group_#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}"
    }
    sg_defs = {
      :num_init_story_days => 60,
      :activated           => false,
      :allow_comments      => true,
      :category            => SocialGroupAttributes::Category::EDUCATIONAL,
      :visibility          => SocialGroupAttributes::Visibility::PUBLIC,
      :membership_mode     => SocialGroupAttributes::MembershipMode::OPEN,
      :listings            => "activity most_recent new_stories starred",
      :default_listing     => "activity",
      :listing_date_window_size => 60
    }

    g = Group.new(g_defs)
    g.sg_attrs = SocialGroupAttributes.new(sg_defs)
    g.save!

    fs_settings   = LayoutSetting.load_settings(nil, g, :featured_story)
    grid_settings = LayoutSetting.load_settings(nil, g, :grid)

    # Make sure the default story actually exists!
    default_story_id = 195567
    default_story_id = Story.find(:last).id if !Story.exists?(default_story_id)

    fs_settings.each { |s|
      case s.name
        when "show_box?" then s.value = "1"
        when "box_title" then s.value = "Practice Review"
        when "story"     then s.value = default_story_id.to_s
      end
    }

    (fs_settings + grid_settings).each { |s|
      s.context = s.context.to_s  # SSS Argh! Symbol-string mismatch yet again .. need to find a good solution for this code pattern
      s.last_edited_by_id = Member.nt_bot.id
      s.save!
    }

    es_attrs = {:page_type => g.class.name, :page_id => g.id, :position => 2, :show_name => false, :context => "right_column"}
    es1 = EditorialSpace.create(es_attrs.merge(:position => 1, :name => "Members"))
    es2 = EditorialSpace.create(es_attrs.merge(:position => 2, :name => "Guide/signup badge"))
    es1.editorial_blocks << EditorialBlock.find_by_slug("group_members")
    es2.editorial_blocks << EditorialBlock.find_by_slug("group_signup_badge")

    return g
  end
end
