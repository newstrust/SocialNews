xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title app_name
    xml.copyright "Copyright (c) 2008-2010 #{app_naem}"
    xml.language "en-us"
    xml.lastBuildDate Time.now.to_s(:rfc822)
    xml.image do
      xml.url home_url + SocialNewsConfig["app"]["mini_logo_path"]
      xml.title app_name
      xml.link home_url
    end
    xml.link @member_profile_url
    xml.description "#{@member.name}'s RSS feed is not available"

	 xml.item do
	   xml.title   "#{@member.name}'s RSS feed is not available"
		xml.pubDate Time.now.to_s(:rfc822)
      xml.guid    @member_profile_url, :isPermaLink => true
		xml.link    @member_profile_url
      xml.description @access_denied_msg
	 end
  end
end
