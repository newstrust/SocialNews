namespace :socialnews do
  desc "Find or create member and grant admin access"
  task( :dev_members => :environment ) do
    admin_role = Role.find_by_name('admin')
    site_admins = YAML::load(File.open("#{RAILS_ROOT}/config/development_accounts.yml"))
    site_admins.each_pair do |k,v|
      admin = Member.find_or_initialize_by_login(v)
      admin_role.members << admin if admin.save
      admin.activate
    end
  end
end
