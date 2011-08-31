module CommentsHelper
  def comment_author_for(comment)
    if comment.member == Member.nt_bot
      "#{SocialNewsConfig["app"]["name"]} Staff"
    else
      link_to comment.member.display_name, member_path(comment.member)
    end
  end

  def in_response_to(comment)
    if comment.parent
      in_response_to_name = (comment.parent.member == Member.nt_bot) ? "#{SocialNewsConfig["app"]["name"]} Staff" : link_to(comment.parent.member.display_name, member_path(comment.parent.member))
      content_tag(:p) do
        "In response to #{link_to 'comment', discussions_comment_path(comment.parent)} by #{in_response_to_name}."
      end
    end
  end

  def comment_page_for(comments, opts ={})
    options = { :current_page => 1 }.merge(opts)
    content_tag(:div, comment_thread_for(comments,options), :id => "comment_page_#{options[:current_page]}")
  end

  def comment_thread_for(comments, opts = {})
    options = {:partial => 'discussions/comments/comment.html.erb', :hostable => nil, :record => nil, :depth_limit => 20, :used_ids => [] }.merge!(opts)
    results = ""
    unless comments.empty? && options[:record].nil?
      options[:record] = comments.first.commentable
      options[:hostable] = options[:record] if options[:record].respond_to?(:hosts)
    end
    comments.each_with_index do |comment, index|
      depth_limit = options[:depth_limit]
      offset = comment.ancestors.size
      unless options[:used_ids].include?(comment.id)
        results << %Q(#{render(:partial => options[:partial], :locals => { :comment => comment, :index => offset, :hostable => options[:hostable] })})
        results << "<div id='comment_#{comment.id}_thread' index='#{offset}'>"
        unless comment.children_count.zero?
          results << comment_thread_for(comment.replies, options) 
        end
        results << "</div>"
      end
    end
    results
  end

  def comment_form_wrapper(&block)
    str = if current_member
      if current_member.can_comment?
        capture(&block)
      else
#        "<p class='comments_disabled'>Commenting is open to all members with a level of #{SocialNewsConfig["min_member_rating_for_comments"]} or more. Read our #{help_link('FAQ', "member_levels", "member")} for more info.</p>"
        "Before you can post a comment, your account must be validated by our staff. To request a validation, please <a href='mailto:#{SocialNewsConfig["email_addrs"]["community"]}?subject=Validation request from #{current_member.name}&body=Hello #{SocialNewsConfig["app"]["name"]},&body=&body=Please validate my account, so I can post stories and comments on #{SocialNewsConfig["app"]["name"]}.&body=&body=Here is my member profile url: #{member_url(current_member)}&body=&body=Thank you,&body=#{current_member.name}'>email us</a>. You first need to #{link_to('fill your profile', my_account_members_url)} and review at least two stories. To learn about account validation and member levels, #{help_link('click here', "member_levels", "member")}."
      end
    else
      link_to_function('Log in to add a comment', "show_login_dialog()", :class => "comment_log_in") + "\n"
    end
    concat(str)
  end

  def link_to_commentable_record(record, str= nil, show_type = true)
    comment_type = record.class == 'Topic' ? record.type.to_s : record.class.to_s
    title = ''
    url = case comment_type
    when "Source"
      title = record.name
      url_for(source_path(record))
    when "Topic"
      title = record.name
      url_for(topic_path(record))
    when "Subject"
      title = record.name
      url_for(subject_path(record))
    when "Story"
      title = record.title
      url_for(story_path(record))
    else
      ""
    end

    # For the purposes of the view subjects are considered topics.
    comment_type = "Topic" if comment_type == 'Subject'
    link_to(str || (show_type ? "#{comment_type}: " : "" ) + "#{title}", url)
  end

  def link_to_commentable_type(comment, str = nil, show_type = true)
    if comment.commentable_type && comment.commentable_id
      record = comment.commentable_type.constantize.send(:find, comment.commentable_id)
      link_to_commentable_record(record,str,show_type)
    end
  end

  def initial_title_for(comment, parent = nil)
    comment_title = nil
    if parent && parent.title
      comment_title = s(parent.title)
    elsif
      comment_title = commentable_type_name_for(comment)
    end
    if parent
      comment_title.nil? ? 'Untitled' : comment_title.sub!(/^[Re: ]*/, "")
      comment_title = "Re: " + (comment_title || 'Untitled')
    end
    comment_title
  end

  def commentable_type_name_for(comment)
    case comment.commentable_type
    when 'Source'
      "Source: #{Source.find(comment.commentable_id).name}"
    when 'Subject'
      "Topic: #{Subject.find(comment.commentable_id).name}"
    when 'Topic'
      "Topic: #{Topic.find(comment.commentable_id).name}"
    else
      nil
    end
  end

  def likable_members_for(comment)
    unless comment.likes.size.zero?
      # cid = CGI::Session.generate_unique_id
      cid = comment.id
      link_to("#{pluralize(comment.likes.size, 'person')}", "#", :id => "likable_members_#{cid}") +
      content_tag(:span, (comment.likes.size==1 ? " likes this comment." : " like this comment."), :id => "likable_members_after_#{cid}" ) +
      content_tag(:div, likable_members(comment.likes), :id =>"likable_members_gallery_#{cid}", :style => 'display:none;', :class => 'likeable') +
      content_tag(:script, :type => 'text/javascript') do
        "$('#likable_members_#{cid}').click(function(event) {
             $('#likable_members_gallery_#{cid}').toggle('slow');
             event.preventDefault();
         });"
      end
    end
  end

  def likable_members(likes)
    result = ''
    likes.each do |like|
      result << content_tag(:ul, :style => "list-style-type: none") do
        content_tag(:li) do
          link_to(image_tag(like.member.image ? like.member.image.public_filename(:thumb) : "/images/ui/silhouette_sml.jpg", :size => "40x40"),like.member) +
          "<br style='clear:both'/>" + 
          content_tag(:small, link_to_member(like.member))
        end
      end
    end
    result
  end

  def available_flags_for(comment)
    content_tag(:ul, flag_links_for(comment), :class => 'inline_list') if current_member
  end

  private
  def flag_links_for(comment, first_item = false)
    results = ""
    Comment.reasons.map do |reason|
      results << content_tag(:li, flag_link(comment, reason), :class => "#{first_item ? "first" : ""}") + ' '
      first_item = false
    end
    results
  end

  def flag_link(comment, reason)
    unless current_member.flags.map{ |x| [x.flaggable_id, x.reason] }.include?([comment.id, reason.to_s])
      case(reason)
      when :flag
        if (current_member && current_member.has_role_or_above?(:admin))
          str = link_to "Flag", "#", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'flaggable'
          str << flag_count(reason, comment)
          str
        else
          str = link_to h(reason.to_s.capitalize), "#", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'flaggable'
          str << content_tag(:span, '', :id => "#{reason}_#{comment.id}", :class => 'grey')
          str
        end
      when :like
        str = link_to "Like" , "#", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'flaggable'
        str << flag_count(reason,comment)
        str
      end
    else
      case(reason)
      when :flag
        if (current_member && current_member.has_role_or_above?(:admin))
          str = link_to str, "Unflag", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'unflaggable'
          str << flag_count(reason,comment)
          str
        else
          link_to 'UnFlag', "#", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'unflaggable'
          str << content_tag(:span, '', :id => "#{reason}_#{comment.id}", :class => 'grey')
          str
        end
      when :like
        str = link_to 'Unlike', "#", :flaggable_id => comment.id, :flaggable_type => comment.class, :reason => h(reason.to_s), :class => 'unflaggable'
        str << flag_count(reason,comment)
        str
      end
    end
  end

  def flag_count(reason, comment)
    reason_count = "#{reason}s_count"
    content_tag(:span, :id => "#{reason_count}_#{comment.id}", :class => 'grey') do
      " (#{comment.send(reason_count.to_sym)})" unless comment.send(reason_count.to_sym).zero?
    end
  end
end
