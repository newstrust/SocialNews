re   = environment()
role = current_role()
case role
  when "solo"
    run "cat #{release_path}/lib/tasks/crontab.#{re}.* > /tmp/crontab.#{re}; crontab /tmp/crontab.#{re}"

  when "app_master"
    run "cd #{release_path}/lib/tasks; cat crontab.#{re}.common crontab.#{re}.master > /tmp/crontab.#{re}; crontab /tmp/crontab.#{re}"

  when "app"
    run "cd #{release_path}/lib/tasks; cat crontab.#{re}.common crontab.#{re}.slave > /tmp/crontab.#{re}; crontab /tmp/crontab.#{re}"
end
run "mkdir -p /home/socialnews/newsletter.logs"
