module Admin::LandingPageHelper
  def use_site_specific_layout?(page_type)
    # For groups, we use a common layout for the national and local sites -- not a site-specific layout
    (page_type || "").downcase == "group" ? false : true
  end

  def clone_spaces_path(opts)
    if opts[:page_id].blank? || opts[:page_type].blank?
      admin_home_path(:action => "clone_editorial_spaces", :from_site => opts[:from_site], :to_site => opts[:to_site])
    else
      case opts[:page_type].downcase
        when "topic"   then clone_editorial_spaces_admin_topic_path(Topic.find(opts[:page_id]),   :page_type => opts[:page_type], :page_id => opts[:page_id], :from_site => opts[:from_site], :to_site => opts[:to_site])
        when "subject" then clone_editorial_spaces_admin_subject_path(Topic.find(opts[:page_id]), :page_type => opts[:page_type], :page_id => opts[:page_id], :from_site => opts[:from_site], :to_site => opts[:to_site])
        when "group"   then clone_editorial_spaces_admin_group_path(Group.find(opts[:page_id]), :page_type => opts[:page_type], :page_id => opts[:page_id], :from_site => opts[:from_site], :to_site => opts[:to_site])
      end
    end
  end

  def page_layout_path(opts = {:page_id => params[:page_id], :page_type => params[:page_type]})
    if opts[:page_id].blank? || opts[:page_type].blank?
      p = admin_home_path
    else
      p = case opts[:page_type].downcase
        when "topic"   then layout_admin_topic_path(Topic.find(opts[:page_id]))
        when "subject" then layout_admin_subject_path(Topic.find(opts[:page_id]))
        when "group"   then edit_admin_group_path(Group.find(opts[:page_id]))
      end
    end
    p + "#sidebar_blocks"
  end
end
