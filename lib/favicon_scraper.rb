require 'open-uri'
require 'net/http'
require 'system_timer'
require 'image_science'
require 'RMagick'

module FaviconScraper
  DEF_ICON = "favicon.ico"
  TIMEOUT  = 10
  SOURCE_DEST_DIR = "public/images/source_favicons"
  FEED_DEST_DIR   = "public/images/feed_favicons"
  HUMAN_HARVESTED_ICON_DIR = "public/images/human_harvested_favicons"

  def self.src_icons_download_dir
    @src_dir ||= "#{SOURCE_DEST_DIR}.#{Time.now.strftime("%y-%m-%d")}"
  end

  def self.feed_icons_download_dir
    @feed_dir ||= "#{FEED_DEST_DIR}.#{Time.now.strftime("%y-%m-%d")}"
  end

  def self.download_from_url(fn, url, dest_dir)
    SystemTimer::timeout(TIMEOUT) {
      resp = NetHelpers.get_response_with_redirect_processing(url)
      case resp
        when Net::HTTPSuccess then
          # Looks like some sites return a 200 even for non-existent files (corpwatch, for ex.)
          body = resp.body
          if (body.length > 0) && (body !~ /<html/i)
            # 1. Save the original
            img_name = url.gsub(%r|.*/|, '')
            tmp_f = "#{dest_dir}/TMP_#{fn}_#{img_name}"
            File.open(tmp_f, "w") { |fh| fh.write(body) }

            # 2. Resize 16x16 using rmagick & store as png
            rm_f = "#{dest_dir}/#{fn}.png"
# SSS: For my local install where rmagick is broken!
#            ImageScience.with_image(tmp_f) {|i| i.resize(16,16) {|ri| ri.save(rm_f); puts "\tIS RESIZED: Stored in #{rm_f}" } }
            img = Magick::Image::read(tmp_f).first
            img.scale(16,16).write(rm_f)
            puts "\tStored in #{rm_f}"
            return true
          else
            return false
          end
      end
    }

    return false
  rescue Exception => e
    puts "Exception: #{e}"
    return false
  end

  def self.try_favicon_with_domain(s, domain)
    def_url = "http://#{domain}/#{DEF_ICON}"
    puts "\tAttempting to get favicon from DEFAULT URL: #{def_url}"
    got_it = download_from_url(s.slug, def_url, src_icons_download_dir)
    if !got_it
      SystemTimer::timeout(TIMEOUT) {
        url = (s.url =~ %r|^http://[^/]*/.*$|) ? s.url : s.url + "/"  # Tack on a trailing / if the url is just the domain!
        resp = NetHelpers.get_response_with_redirect_processing(url)
        body = resp.body
          # Ex: 1. <link rel="shortcut icon" href="/images/favicon.gif" type="image/gif" />
          #     2. <link href='http://farm4.static.flickr.com/3165/2593478460_0e96f4b611_o.gif' rel='shortcut icon' type='image/vnd.microsoft.icon'/>
        favicon_url_line = $1 if body =~ %r{(<link[^<>]*?rel=["']shortcut\s*icon["'][^<>]*?>)}imx
        favicon_url = $1 if favicon_url_line && (favicon_url_line =~ %r{href=["']([^'"<>]*?)["']}imx)

          # If you didn't find it with a 'shortcut icon' rel link, try looking for a 'icon' rel link
        if !favicon_url
          favicon_url_line = $1 if body =~ %r{(<link[^<>]*?rel=["']icon["'][^<>]*?>)}imx
          favicon_url = $1 if favicon_url_line && (favicon_url_line =~ %r{href=["']([^'"<>]*?)["']}imx)
        end

          # Download!
        if favicon_url
          if favicon_url !~ %r|http://|
            root = (favicon_url =~ %r|^/|) ? domain.gsub(%r|/.*|, "") : domain ## BUGGY! If redirected, cannot use domain .. okay for now
            favicon_url.gsub!(%r|^/|, "")
            favicon_url = "http://#{root}/#{favicon_url}"
          end
          favicon_url = URI.encode(favicon_url) # Encode url because some uris come out with spaces!
          puts "\tAttempting to get favicon from REL LINK URL: #{favicon_url}"
          got_it = download_from_url(s.slug, favicon_url, src_icons_download_dir)
        end
      }
    end
    got_it
  end

  def self.download_source_favicon(s)
    if s.url.blank?
      puts "---- Missing url for source #{s.id}:#{s.name}. Skipping!"
      return
    end
    got_it = try_favicon_with_domain(s, s.domain)
    got_it = try_favicon_with_domain(s, "www.#{s.domain}") if !got_it
    puts "\tNo favicon!" if !got_it
  rescue Exception => e
    puts "Exception: #{e}"
    puts "\tNo favicon!"
  end

  def self.download_feed_favicon(f)
    if f.is_twitter_feed?
      img_url = FeedHelpers.fetch_favicon_url(f)
      got_it = img_url ? download_from_url("feed_#{f.id}", img_url, feed_icons_download_dir) : false
      puts "\tNo favicon!" if !got_it
    elsif f.source_profile_id
      s = Source.find(f.source_profile_id)
      if !s.favicon.blank?
        src_favicon = "public#{s.favicon}"
        puts "\tCopying #{src_favicon} to #{feed_icons_download_dir}/feed_#{f.id}.png"
        system("cp #{src_favicon} #{feed_icons_download_dir}/feed_#{f.id}.png")
      end
    end
  rescue Exception => e
    puts "Exception: #{e}"
    puts "\tNo favicon!"
  end

  def self.cache_source_favicons
    system("mkdir -p #{src_icons_download_dir}")
    Source.find(:all, :conditions => "status in ('list', 'hide') AND slug IS NOT NULL", :select => "id").each { |s| 
      s = Source.find(s.id)
      sfi = s.favicon
      if sfi.blank?
        puts "Attempting favicon download for #{s.id}:#{s.name}"
        download_source_favicon(s)
      else
        puts "Favicon #{sfi} exists for #{s.id}:#{s.name}"
      end
    }
#    system("ls #{src_icons_download_dir}/*_ORIG_* | sed 's/public\\/images\\/source_favicons\\/\\(.*\\)(_ORIG_.*)/\\1; <img src=\"images\\/source_favicons\\/\\1\\2\">Orig; <img src=\"images\\/source_favicons\\/IS_\\1.png\">ImageScience;<img src=\"images\\/source_favicons\\/RM_\\1.png\">RMagick;<br\\/>/g;' > public/favicons_debug.html")
    system("rm #{src_icons_download_dir}/TMP_*")
#    system("cp #{src_icons_download_dir}/* #{SOURCE_DEST_DIR}/")
#    system("cp #{HUMAN_HARVESTED_ICON_DIR}/* #{SOURCE_DEST_DIR}/")
  end

  def self.cache_feed_favicons
    system("mkdir -p #{feed_icons_download_dir}")
    default_favicon = "/images/ui/feed_favicon.png"
    Feed.find(:all, :select => "id").each { |f| 
      f = Feed.find(f.id)
      ffi = f.favicon
      if ffi =~ %r|#{default_favicon}|
        puts "Attempting favicon download for #{f.id}:#{f.name}:#{f.subtitle}"
        download_feed_favicon(f)
      else
        puts "Favicon #{ffi} exists for #{f.id}:#{f.name}:#{f.subtitle}"
      end
    }
    system("rm #{feed_icons_download_dir}/TMP_*")
#    system("cp #{feed_icons_download_dir}/* #{FEED_DEST_DIR}/")
#    system("cp #{HUMAN_HARVESTED_ICON_DIR}/feeds/*.png #{FEED_DEST_DIR}/")
  end
end
