namespace :socialnews do
  task :post_deploy => :environment do
    `touch /tmp/post_deploy.log; echo > /tmp/post_deploy.log`
    ["socialnews:gen_taxonomies", "socialnews:stories:gen_decay_script", "socialnews:update_favicons", "ts:stop", "ts:config", "ts:index", "ts:start"].each { |t|
      begin
        Rake::Task[t].invoke
      rescue Exception => e
        `echo "Exception #{e} running task #{t}" >> /tmp/post_deploy.log`
      end
    }
    `echo 'all done!' >> /tmp/post_deploy.log` 
  end
end
