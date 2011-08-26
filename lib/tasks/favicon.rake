namespace :socialnews do
  desc "Cache source favicons"
  task(:cache_source_favicons => :environment) do
    FaviconScraper.cache_source_favicons
  end

  desc "Update favicons with human harvested ones"
  task(:update_favicons => :environment) do
    begin
      system("cp #{FaviconScraper::HUMAN_HARVESTED_ICON_DIR}/*.png #{FaviconScraper::SOURCE_DEST_DIR}/")
      system("cp #{FaviconScraper::HUMAN_HARVESTED_ICON_DIR}/feeds/*.png #{FaviconScraper::FEED_DEST_DIR}/")
    rescue
    end
  end
end
