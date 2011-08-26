module LocalSitesHelper
  def page_template(local_site, page_slug, default_template)
    if local_site
      template_dir = "pages/local_sites/#{local_site.slug}/"
      File.exists?("#{RAILS_ROOT}/app/views/#{template_dir}_#{page_slug}.html.erb") ? template_dir + page_slug : default_template
    else
      default_template
    end
  end
end
