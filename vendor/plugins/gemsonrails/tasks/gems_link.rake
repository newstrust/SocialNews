namespace :gems do
  desc "Link a RubyGem into this Rails application; init.rb will be loaded on startup."
  task :link do
		unless gem_name = ENV['GEM']
		  puts <<-eos
Parameters:
  GEM      Name of gem (required)

  
eos
      break
		end

    require 'rubygems'
    Gem.manage_gems
    
    gem = Gem.cache.search(gem_name).sort_by { |g| g.version }.last
    version ||= gem.version.version rescue nil
    
    unless gem && path = Gem::UnpackCommand.new.get_path(gem_name, version)
      raise "No gem #{gem_name} is installed.  Try 'gem install #{gem_name}' to install the gem."
    end
    
    gems_dir = File.join(RAILS_ROOT, 'vendor', 'gems')
    mkdir_p gems_dir, :verbose => false if !File.exists?(gems_dir)
    
    target_dir = ENV['TO'] || gem.name
    rm_rf "vendor/gems/#{target_dir}", :verbose => false
    
    chdir gems_dir, :verbose => false do
      mkdir_p target_dir + '/tasks', :verbose => false
      chdir target_dir, :verbose => false do
        File.open('init.rb', 'w') do |file|
          file << <<-eos
require 'rubygems'
Gem.manage_gems
gem = Gem.cache.search('#{gem.name}').sort_by { |g| g.version }.last
if gem.autorequire
  require gem.autorequire
else
  require '#{gem.name}'
end
eos
        end
        File.open(File.join('tasks', 'load_tasks.rake'), 'w') do |file|
          file << <<-eos
# This file does not include any Rake files, but loads up the 
# tasks in the /vendor/gems/ folders
require 'rubygems'
Gem.manage_gems
gem = Gem.cache.search('#{gem.name}').sort_by { |g| g.version }.last
raise \"Gem '#{gem.name}' is not installed\" if gem.nil?
path = gem.full_gem_path
Dir[File.join(path, "/**/tasks/**/*.rake")].sort.each { |ext| load ext }
eos
        end
        puts "Linked #{gem_name} (currently #{version}) via 'vendor/gems/#{target_dir}'"
      end
    end
  end

  task :unfreeze do
    raise "No gem specified" unless gem_name = ENV['GEM']
    Dir["vendor/gems/#{gem_name}-*"].each { |d| rm_rf d }
  end
end