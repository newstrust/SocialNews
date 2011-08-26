namespace :socialnews do
  namespace :newsletter do
    def get_newsletter_type_for_task(task_name)
      valid_types = Newsletter::VALID_NEWSLETTER_TYPES
      unless ENV.include?("freq") && valid_types.include?(ENV['freq'])
        raise "usage: rake [RAILS_ENV=env_here] socialnews:newsletter:#{task_name} freq=NL_TYPE_HERE  # valid newsletter_types are #{valid_types * ','}"
      end

      ENV['freq']
    end

    desc "Schedule a newsletter"
    task(:schedule => :environment) do
      nl_type = get_newsletter_type_for_task("schedule")

      ## Create a new newsletter right away (it will be scheduled automatically)
      nl = Newsletter.fetch_latest_newsletter(nl_type, Member.nt_bot)
      if (nl.state == Newsletter::IN_TRANSIT)
        Mailer.deliver_admin_alert("The latest #{nl_type} newsletter is marked 'in_transit' even after being dispatched!  It should have been marked 'sent'.  Please investigate!  No new newsletter has been scheduled for delivery.  After resolving the issue, please schedule a new #{nl_type} newsletter manually via the 'socialnews:newsletter:schedule' rake task.  In the case of weekly/daily newsletters, you can also do this via the admin interface.")
      end
    end

    desc "Dispatches most recent daily/weekly newsletter right now!"
    task(:dispatch => :environment) do
      nl_type = get_newsletter_type_for_task("dispatch")
      begin
        require 'lib/newsletter_mass_mailer'
        NewsletterMassMailer.dispatch(nl_type)
      rescue Exception => e
        RAILS_DEFAULT_LOGGER.error "Newsletter Mass Mailing Exception: #{e}\n#{e.backtrace.inspect}"
      end

      ENV["freq"] = nl_type
      Rake::Task["socialnews:newsletter:schedule"].invoke
    end

    desc "Clear pending dispatch jobs"
    task(:clear_pending_dispatches => :environment) do
      Newsletter.clear_pending_dispatches(get_newsletter_type_for_task("clear_pending_dispatches"))
    end
  end
end
