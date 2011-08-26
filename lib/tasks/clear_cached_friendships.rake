namespace :socialnews do
  desc "Clear cached social network friendships"
  task(:clear_cached_friendships => :environment) do
    SocialNetworkFriendship.delete_all
    FacebookConnectSettings.update_all("friendships_cached = false")
    TwitterSettings.update_all("friendships_cached = false")
  end
end
