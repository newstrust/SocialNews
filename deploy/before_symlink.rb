rails_env = environment()
role = current_role()
run "crontab -r" # Remove crontab so that sphinx reindex doesn't kick off
run "ln -nsf #{release_path}/public/images #{release_path}/public/Images && ln -s #{release_path}/REVISION #{release_path}/public/revision.txt"
run "cd #{release_path}; rake #{rails_env} socialnews:post_deploy"
