require 'ruby-debug'
class ActsAsTaggableExtendedGenerator < Rails::Generator::Base

  default_options :skip_migration => false
                    
  def initialize(runtime_args, runtime_options = {})
    super
    @rspec = has_rspec?
  end
  
  def manifest
    recorded_session = record do |m|
      m.template 'tag.rb',
                  File.join('app/models', "tag.rb")
     
      m.template 'tagging.rb',
                  File.join('app/models', "tagging.rb")
      
      m.template 'acts_as_tagger.rb',
                  File.join('lib', 'acts_as_tagger.rb')
     
      m.template 'acts_as_taggable.rb',
                 File.join('lib', 'acts_as_taggable.rb')
     
      if @rspec
        m.template 'taggings.yml',
                    File.join('spec/fixtures',
                              "taggings.yml")
        
        m.template 'tags.yml',
                   File.join('spec/fixtures',
                   "tags.yml")

      else
        # Unit tests needed.
      end
     
      unless options[:skip_migration]
        m.migration_template 'migration.rb', 'db/migrate', 
         :assigns => { :migration_name => "ActsAsTaggableMigration" },
         :migration_file_name => "acts_as_taggable_migration"
      end
    end

    action = nil
    action = $0.split("/")[1]
    case action
      when "generate" 
        puts
        puts ("-" * 70)
        puts "Success!"
        puts
        puts "Dont't Forget to:"
        puts "  - Add the tagger and taggable mixins to config/environment.rb"
        puts "      require 'acts_as_taggable'"
        puts "      require 'acts_as_tagger'"
        puts
        unless options[:skip_migration]
        puts "  - Run the migration."
        puts "      rake db:migrate"
        end
        puts
        puts
        puts ("-" * 70)
        puts
        puts "Look for the Tag and Tagging models in /app/models/"
        puts "Look for the acts_as_* mixin methods in /app/lib/"
        puts ("-" * 70)
        puts
      else
        puts
    end

    recorded_session
  end

  def has_rspec?
    options[:rspec] || (File.exist?('spec') && File.directory?('spec'))
  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} extend_taggable ModelName"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-migration", 
             "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
      opt.on("--rspec",
             "Force rspec mode (checks for RAILS_ROOT/spec by default)") { |v| options[:rspec] = true }
    end
end