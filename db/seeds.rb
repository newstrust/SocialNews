# Create an image that mimics an uploaded attachment
def create_image(image_path, credit=nil, credit_url=nil)
  return nil if !File.exists?(image_path)

  w, h = 0,0
  ImageScience.with_image(image_path) { |i| w, h = i.width, i.height }
  size = File.new(image_path).lstat.size
  ctype = "image/jpeg" if (image_path =~ /\.jpe?g/i)
  ctype = "image/gif" if (image_path =~ /\.gif/i)
  ctype = "image/png" if (image_path =~ /\.png/i)
  i = Image.new(:filename => image_path, :size => size, :width => w, :height => h, :content_type => ctype, :credit => credit, :credit_url => credit_url)
  i.temp_path = image_path # Required so that this image is treated as an uploaded attachment
  return i
end

def file_fields(file_path, separator=",")
  puts "----- Processing file #{file_path} -----"
  i = 0
  File.open(file_path).each_line { |l| 
    l.strip! 
    yield l.split(separator), l, i
    i += 1
  }
end

def source_file_fields(sources, file_path, separator=",")
  file_fields(file_path, separator) { |fields, line, line_num|
    s = sources[fields[0]]
    if s.nil?
      puts "ERROR: could not find source for #{fields[0]} from line number #{line_num}.  Ignoring this line."
      next
    end

    yield fields, s
  }
end

#--------------- Initialize roles ---------------
roles = [ {:name => "Admin", :description => "Administrators with all privileges", :context => Group::GroupType::ROLE, :is_protected => 1, :slug => "admin"},
          {:name => "Staff", :description => "Organizational Staff", :context => Group::GroupType::ROLE, :is_protected => 1, :slug => "staff"},
          {:name => "Editors", :description => "Editors", :context => Group::GroupType::ROLE, :is_protected => 1, :slug => "editor"},
          {:name => "Hosts", :description => "Hosts", :context => Group::GroupType::ROLE, :is_protected => 1, :slug => "host"} ]

roles.each { |attrs|
  if !Group.exists?(attrs)
    puts "creating role #{attrs[:name]}"
    Group.create!(attrs) 
  else
    puts "role #{attrs[:name]} already exists"
  end
}

#--------------- Initialize members -----------------
# IMPORTANT: Do not delete the first 3 members (bot, anonymous, tagger).  These accounts have to be present with ids 1, 2, and 3.  If you want to change
# the ids or dont want to depend on this, edit app/models/member.rb and fix the methods "nt_bot", "nt_anonymous", and "nt_tagger".
members = [ {:name => "Bot", :email => "bot@socialnews.com", :status => "guest", :profile_status => "hide", :password => "bot", :password_confirmation => "bot"},
            {:name => "Anonymous member", :email => "bot+anonymous@socialnews.com", :status => "guest", :profile_status => "hide", :password => "anonymous", :password_confirmation => "anonymous"},
            {:name => "Auto Tagger", :email => "bot+tagger@socialnews.com", :status => "guest", :profile_status => "hide", :password => "tagger", :password_confirmation => "tagger"},
            {:name => "Administrator", :email => "admin@socialnews.com", :status => "member", :profile_status => "hide", :password => "admin", :password_confirmation => "admin", :validation_level => 5},
            {:name => "Editor", :email => "editor@socialnews.com", :status => "member", :profile_status => "show", :password => "editor", :password_confirmation => "editor", :validation_level => 5} ]

members.each { |attrs| 
  if !Member.exists?(:email => attrs[:email])
    puts "creating member #{attrs[:name]}"
    Member.create!(attrs) 
  else
    puts "member #{attrs[:name]} already exists"
  end
}

#--------------- Assign admin member to the admin role --------------
[["Administrator", "admin"], ["Editor", "editor"]].each { |mname, rslug|
  role = Group.find_by_slug(rslug)
  member = Member.find_by_name(mname)
  if !role.members.include?(member)
    role.members << member 
    puts "Assigned #{member.name} to #{role.name} role"
  else
    puts "#{member.name} has already been assigned to #{role.name} role"
  end
}

#--------------- Initialize subjects --------------
TopicRelation.topic_constants["topic_subjects"].each { |row| 
  slug = row.keys.first 
  attrs = row[slug]
  name = attrs["name"]
  groupings = attrs["groupings"]
  topic_volume = attrs["topic_volume"]
  t = Tag.find_or_create_by_name_and_slug_and_tag_type(name, slug, "Subject")
  s = Subject.find_by_tag_id(t.id)
  if s.nil?
     puts "Creating subject #{name}"
     s = Subject.create!(:tag_id => t.id, :name => name, :slug => slug, :type => "Subject", :topic_volume => topic_volume)
  else
     puts "subject #{name} already exists with id #{s.id}"
  end
  tr = TopicRelation.find_or_create_by_topic_id_and_related_topic_id(s.id, s.id)
  tr.update_attributes(:context => 'subject')
}

#--------------- Initialize editorial blocks --------------
eb = EditorialBlock.find_by_slug("test1")
if eb.nil?
  eb = EditorialBlock.create!(:body => "<b> This is a test block</b>. Replace this with what you want by clicking the Admin link in the navbar. HTML verification is NOT done on this code.", :slug => "test1", :context => "right_column")
  puts "Created editorial block test1"
else
  puts "Editorial block test1 exists"
end

["recent_reviewers", "recent_reviews", "featured_review"].each { |ebslug|
  eb = EditorialBlock.find_by_slug(ebslug)
  if eb.nil?
    eb = EditorialBlock.create!(:slug => ebslug, :context => "right_column")
    puts "Created editorial block #{ebslug}"
  else
    puts "Editorial block #{ebslug} exists"
  end
}

#--------------- Initialize editorial spaces for all predefined code blocks plus the test block above --------------
[["Developers Test", true], ["Our Reviewers", true], ["Recent Reviews", false], ["Featured Review", true]].each_with_index { |esargs, i|
  esname = esargs[0]
  show_name = esargs[1]
  es = EditorialSpace.find_by_name(esname)
  if es.nil?
    es = EditorialSpace.create!(:name => esname, :context => "right_column", :show_name => show_name, :position => i+1)
    puts "Created editorial space #{esname}:#{i}"
  else
    puts "Editorial space #{esname}:#{i} exists"
  end
}

#------------- Assign blocks to spaces ----------------
[["Developers Test", "test1"], ["Our Reviewers", "recent_reviewers"], ["Recent Reviews", "recent_reviews"], ["Featured Review", "featured_review"]].each { |esname, ebslug|
  es = EditorialSpace.find_by_name(esname)
  eb = EditorialBlock.find_by_slug(ebslug)
  es.editorial_blocks << eb if !es.editorial_blocks.include?(eb)
}

#------------ Predefined page templates ---------------
common_hdr = <<eof
<div class="span-16 white_box" style="margin-top:0px;">
  <div class="top"></div>
  <div class="wrapper">
    <div class="interior_content" style="font-size:1.17em;line-height:1.25em;">
eof

common_body = <<eof
This SocialNews code base is an open source version of the <a href="http://newstrust.net" target="_blank">NewsTrust.net</a> platform. 
To find out more about NewsTrust, <a href="http://newstrust.net" target="_blank">visit their site</a>. 

To inquire about their consulting services, email partners-at-newstrust.net."
eof

common_ftr = <<eof
    </div>
  </div>
  <div class="bottom"></div>
</div>
eof

groups_template = common_hdr + "<h2> Groups </h2>" + common_body + "<p>Here is a link to <a href='http://newstrust.net/groups' target='_blank'>NewsTrust groups page</a>.</p>" + common_ftr
mynews_template = common_hdr + "<h2> MyNews </h2>" + common_body + "<p>Here is a link to <a href='http://newstrust.net/about/mynews' target='_blank'>NewsTrust MyNews page</a>.</p>" + common_ftr
newshunts_template = common_hdr + "<h2> News Hunts </h2>" + common_body + "<p>Here is a link to <a href='http://newstrust.net/newshunts' target='_blank'>NewsTrust News Hunts page</a>.</p>" + common_ftr
[["groups", groups_template], ["about_mynews", mynews_template], ["newshunts", newshunts_template]].each { |slug, template|
  pkv = PersistentKeyValuePair.find(:first, :conditions => {"persistent_key_value_pairs.key" => "#{slug}_template"})
  if pkv.nil?
    PersistentKeyValuePair.create!("key" => "#{slug}_template", :value => template) 
    puts "Created page template: #{slug}_template"
  else
    puts "Page template #{slug}_template exists"
  end
}

#------------ Seed sources with existing data dump ----------
sources = {}

# File 1: comma-separated file of basic source attributes
#    id, name, slug, domain, ownership, section, status, url, is_framebuster
file_fields("db/seed_data/sources/basic.csv") { |fields, line, line_num|
  s = Source.find_by_slug(fields[2])
  if !s.nil?
    puts "Source for #{fields[0]} exists"
  else
    puts "Creating source for #{fields[0]}"
    attrs = {}
    %w(name slug domain ownership section status url is_framebuster).each_with_index { |key, i| attrs[key] = fields[i+1] }
    s = Source.create!(attrs)
  end
  sources[fields[0]] = s
}

# File 2: |-separated file of additional attributes
# id, source_names_other, online_access, source_text, description_link_address, description_link_source_name, journalist_names_featured, source_managers, source_owners, source_organization_type, source_address1, source_address2, source_city, source_country, source_state, source_zip, source_scope, source_language, source_other_tags, source_duplicate_links, source_web_contact_address, source_public_email_address, source_public_phone_number, contact_source_status, source_logo_status, political_viewpoint, source_edit_notes
source_file_fields(sources, "db/seed_data/sources/additional_attrs.csv", "|") { |fields, s|
  puts "Creating source attrs for #{fields[0]}"

  %w(source_names_other online_access source_text description_link_address description_link_source_name journalist_names_featured source_managers source_owners source_organization_type source_address1 source_address2 source_city source_country source_state source_zip source_scope source_language source_other_tags source_duplicate_links source_web_contact_address source_public_email_address source_public_phone_number contact_source_status source_logo_status political_viewpoint source_edit_notes).each_with_index { |key, i|
    s.update_attribute(key, fields[i+1])
  }
}

# File 3: comma-separated file of source media data
source_file_fields(sources, "db/seed_data/sources/source_medium.csv") { |fields, s|
  if !s.source_media.empty?
    puts "Source #{s.name} already has source media assigned to it"
  else
    puts "Creating source media for #{s.name}"
    fields[1..fields.length].each_with_index { |medium, i| s.source_media << SourceMedium.new(:main => (i == 0), :medium => medium) }
  end
}

# File 4: source images
source_file_fields(sources, "db/seed_data/sources/images.csv") { |fields, s|
  next if fields[1].nil?

  if !s.image.nil?
    puts "Source #{s.name} has an image already"
    next
  end

  puts "Creating source image for #{s.name}"
  s.image = create_image("db/images/sources/#{fields[1]}")
  s.save!
  s.image.save! if s.image
}

# File 5: favicons
system("mkdir -p public/images/source_favicons")
source_file_fields(sources, "db/seed_data/sources/favicons.csv") { |fields, s|
  next if fields[1].nil?

  puts "Saving source favicon for #{s.name}"
  image_path = "db/images/source_favicons/#{fields[1]}"
  system("cp #{image_path} public/images/source_favicons")
}

#------------ Seed topics with existing data dump ----------
# File 1: |-separated file of basic topic attributes
#    name, slug, intro, image, image_credits, image_credit_url
file_fields("db/seed_data/topics/basic.csv", "|") { |fields, line, line_num|
  t = Topic.find_by_slug(fields[1])
  if !t.nil?
    puts "Topic for #{fields[0]} exists.  Ignoring line #{line_num}"
  else
    puts "Creating topic for #{fields[0]}"
    attrs = {}
    tag = Tag.create!(:name => fields[0], :slug => fields[1], :tag_type => "Topic")
    t = Topic.create!(:name => fields[0], :slug => fields[1], :tag_id => tag.id, :intro => fields[2])
    t.save!
  end

  if t.image.nil? && !fields[3].blank?
    puts "Creating topic image for #{t.name}"
    t.image = create_image("db/images/topics/#{fields[3]}", fields[4], fields[5])
    t.image.save! if t.image
  end
}

# File 2: comma-separated file of taxonomy
#    name, containing subject, subject grouping
file_fields("db/seed_data/topics/taxonomy.csv") { |fields, line, line_num|
  t = Topic.find_by_name(fields[0])
  if t.nil?
    puts "ERROR: could not find topic for #{fields[0]} from line number #{line_num}.  Ignoring this line."
    next
  end

  s = Subject.find_by_name(fields[1])
  if s.nil?
    puts "Subject for topic #{t.name} is nil!"
  elsif TopicRelation.exists?(:topic_id => t.id, :related_topic_id => s.id)
    puts "topic #{fields[0]} already belongs to subject #{fields[1]}"
  else
    puts "Adding topic #{fields[0]} to subject #{fields[1]}"
    TopicRelation.create(:topic_id => t.id, :related_topic_id => s.id, :context => "subject", :grouping => fields[2])
  end
}

#------------ Seed feeds with existing data dump ----------
# File 1: |-separated file of basic feed attributes
#    name, subtitle, url, description, home_page, feed_level, feed_type, feed_group, default_topics
file_fields("db/seed_data/feeds.csv", "|") { |fields, line, line_num|
  f = Feed.find_by_url(fields[2])
  if !f.nil?
    puts "Feed for #{fields[2]} exists.  Ignoring line #{line_num}"
  else
    puts "Creating feed for #{fields[2]}."
    attrs = {:auto_fetch => true}
    %w(name subtitle url description home_page feed_level feed_type feed_group).each_with_index { |key,i| attrs[key] = fields[i] }
    f = Feed.create!(attrs)
    f.update_attribute("default_topics", fields[8].split(",").map(&:strip).reject { |tslug| Topic.find_by_slug(tslug).nil? } * ", ")
  end
}
