class ShortUrl < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :page, :polymorphic => true

  named_scope :for_site, lambda { |s|  { :conditions => { :local_site_id => s ? s.id : nil } } }
  named_scope :for_page, lambda { |p_type, p_id| { :conditions => { :page_type => p_type, :page_id => p_id } } }

  TOOLBAR = "toolbar"

  BITLY_LOGIN   = SocialNewsConfig["bitly"]["login"]
  BITLY_API_KEY = SocialNewsConfig["bitly"]["api_key"]
  def self.shorten_url(link)
    # No more than 10 seconds!
    SystemTimer::timeout(10) {
      open("http://api.bit.ly/v3/shorten?login=#{BITLY_LOGIN}&apiKey=#{BITLY_API_KEY}&format=txt&longUrl=#{link}", {"UserAgent" => SocialNewsConfig["app"]["name"]}).read.strip
    }
  rescue
    RAILS_DEFAULT_LOGGER.error "Timed out trying to fetch bit.ly url for #{link}"
    link
  end

#  def self.short_url(page, page_url, local_site = nil)
#    ls_id = local_site ? local_site.id : nil
#       ShortUrl.find(:first, :conditions => {:page_id => page.id, :page_type => page.class.name, :local_site_id => ls_id }) \
#    || ShortUrl.create(:page_id => page.id, :page_type => page.class.name, :local_site_id => ls_id, :short_url => shorten_url(page_url))
#  end

  def self.add_or_update_short_url(opts)
    opts[:url_type]   ||= nil
    opts[:local_site] ||= nil
    if opts[:page]
      page = opts.delete(:page)
      opts[:page_type] = page.class.name
      opts[:page_id] = page.id
    end

    su = ShortUrl.for_site(opts[:local_site]).for_page(opts[:page_type], opts[:page_id]).find(:first, :conditions => {:url_type => opts[:url_type]})
    if su.nil?
      opts[:local_site_id] = opts[:local_site] ? opts[:local_site].id : nil
      opts.delete(:local_site)
      ShortUrl.create(opts)
    else
      su.update_attribute(:short_url, opts[:short_url])
    end
  end
end
