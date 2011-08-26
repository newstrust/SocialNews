# see http://errtheblog.com/posts/31-rake-around-the-rosie

%w[development production staging].each do |env|
  desc "Runs the following task in the #{env} environment" 
  task env do
    RAILS_ENV = ENV['RAILS_ENV'] = env
  end
end
