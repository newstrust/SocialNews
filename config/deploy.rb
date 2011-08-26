# Please install the Engine Yard Capistrano gem
# gem install eycap --source http://gems.engineyard.com

require "eycap/recipes"

# =============================================================================
# ENGINE YARD REQUIRED VARIABLES
# =============================================================================
# You must always specify the application and repository for every recipe. The
# repository must be the URL of the repository you want this recipe to
# correspond to. The :deploy_to variable must be the root of the application.

set :keep_releases,       5
set :application,         "newstrust"
set :repository,         "svn-repository-url-here"
set :scm_username,       "svn-uid"
set :scm_password,       "svn-password"
set :user,               "deploy-uid"
set :password,           "deploy-password"
set :deploy_to,           "/data/#{application}"
set :deploy_via,          :filtered_remote_cache
set :repository_cache,    "/var/cache/engineyard/#{application}"
set :monit_group,         "newstrust"
set :scm,                 :subversion
set :runner,							"newstrust"
set :production_database, "newstrust_production"
set :production_dbhost,   "mysql50-10-master"
set :staging_database, "newstrust_staging"
set :staging_dbhost,   "mysql50-staging-1"
set :dbuser,        "newstrust_db"
set :dbpass,        "wetr97uF"

# comment out if it gives you trouble. newest net/ssh needs this set.
ssh_options[:paranoid] = false

# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.
task :staging do
  role :web, "74.201.254.36:8272" # newstrust [mongrel] [mysql50-staging-1]
  role :app, "74.201.254.36:8272", :mongrel => true, :sphinx => true
  role :db , "74.201.254.36:8272", :primary => true
  
  set :rails_env, "staging"
  set :environment_database, defer { staging_database }
  set :environment_dbhost, defer { staging_dbhost }
end

task :production do
  role :web, "74.201.254.36:8413" # newstrust [mongrel,sphinx] [mysql50-staging-1,mysql50-10-master]
  role :app, "74.201.254.36:8413", :mongrel => true, :sphinx => true
  role :db , "74.201.254.36:8413", :primary => true
  role :app, "74.201.254.36:8414", :no_release => true, :no_symlink => true, :mongrel => true, :sphinx => true
  
  set :rails_env, "production"
  set :environment_database, defer { production_database }
  set :environment_dbhost, defer { production_dbhost }
end

# SHARED DEV SERVER: mod_rails running on a VPS offsite (*not* at EngineYard!)
task :shared_dev do
  role :web, "67.207.148.73"
  role :app, "67.207.148.73" #, :mongrel => true, :sphinx => true
  role :db , "67.207.148.73", :primary => true
  set :deploy_to, "/var/www/#{application}-dev"
  set :user, "capistrano"
  set :password, "barsnotstars"
  set :rails_env, "shared_dev"
  set :deploy_via, :export
  
  # overrides
  namespace :sphinx do task :configure do end end
  namespace :deploy do
    %w(start restart).each { |name| task name, :roles => :app do run "touch #{release_path}/tmp/restart.txt" end }
  end
  task :newstrust_custom, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
    run <<-CMD
    mv #{release_path}/config/database.deploy #{release_path}/config/database.yml &&
    sed -i -e 's/Options \+FollowSymLinks/#Options \+FollowSymLinks/' #{release_path}/public/.htaccess
    CMD

    # same as below, minus sphinx stuff
    run <<-CMD
    ln -nsf #{shared_path}/photos #{release_path}/public/images/photos &&
    rm #{release_path}/public/images/icons &&
    ln -nsf #{shared_path}/icons #{release_path}/public/images/icons &&
    ln -nsf #{release_path}/public/images #{release_path}/public/Images &&
    ln -s #{release_path}/REVISION #{release_path}/public/revision.txt &&
    rm -rf #{release_path}/public/images/source_favicons &&
    ln -nsf #{shared_path}/source_favicons #{release_path}/public/images/source_favicons
    CMD
  end
end


# =============================================================================
# Any custom after tasks can go here.
#after "deploy:symlink_configs", "newstrust_custom"
#task :newstrust_custom, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
#  run <<-CMD
#  ln -sf #{shared_path}/config/staging.rb #{release_path}/config/environments/
#  CMD
#end
# =============================================================================
task :newstrust_custom, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
  run <<-CMD
  ln -nsf #{shared_path}/photos #{release_path}/public/images/photos &&
  ln -nfs #{shared_path}/config/sphinx.yml #{release_path}/config/sphinx.yml &&
  ln -nfs #{shared_path}/config/thinkingsphinx #{release_path}/config/thinkingsphinx &&
  rm #{release_path}/public/images/icons &&
  ln -nsf #{shared_path}/icons #{release_path}/public/images/icons &&
  ln -nsf #{release_path}/public/images #{release_path}/public/Images &&
  ln -s #{release_path}/REVISION #{release_path}/public/revision.txt &&
  rm -rf #{release_path}/public/images/source_favicons &&
  ln -nsf #{shared_path}/source_favicons #{release_path}/public/images/source_favicons
  CMD
  rails_env = fetch(:rails_env, "production")
  run("cd #{release_path}; rake #{rails_env} newstrust:gen_taxonomies; rake #{rails_env} newstrust:stories:gen_decay_script; rake #{rails_env} newstrust:update_favicons")
end

# legacy_migration rake task wrapper
namespace :newstrust do
  namespace :legacy_data do
    desc "Import legacy data (including images) and re-process all ratings"
    task :migrate do
      run("cd #{deploy_to}/current; rake staging newstrust:legacy_data:migrate -q")
    end
  end

  namespace :bleak_house do
    desc "Starts one of the mongrels under bleakhouse"
    task :start, :roles => :app do
      #sudo "/usr/bin/monit stop mongrel_newstrust_5000 -g #{monit_group}"
      sudo "/usr/bin/monit stop all -g #{monit_group}"
      sudo "/data/bleak_house/start"
    end

    desc "Stops the bleahouse-started mongrel"
    task :stop, :roles => :app do
      sudo "/data/bleak_house/stop"
      #sudo "/usr/bin/monit start mongrel_newstrust_5000 -g #{monit_group}"
    end
  end
end

# Do not change below unless you know what you are doing!

after "deploy", "deploy:cleanup"
after "deploy:migrations" , "deploy:cleanup"
after "deploy:update_code", "deploy:symlink_configs"
after "deploy:symlink_configs", "newstrust_custom"
after "newstrust_custom", "sphinx:configure"

# uncomment the following to have a database backup done before every migration
# before "deploy:migrate", "db:dump"

