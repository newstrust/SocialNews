#	We will explicitly manage Bj in all environments, so set no_tickle to true!
# When starting with an empty db, none of these tables exist!
# So, check first before trying to configure Bj
if (Bj::Table::Config.table_exists?)
  Bj.config["#{RAILS_ENV}.no_tickle"] = true
end
