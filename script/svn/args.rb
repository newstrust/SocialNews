# command-line parser 
require 'optparse'
require 'ostruct'

class OptParse
  def self.parse(args)
    #available_branches = Dir.new("../../branches").select { |b|
    #  File.directory?("../../branches/#{b}") and b !~ /^^\./
    #}
    
    options = OpenStruct.new
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0, '.*')} [options] <path>"
      opts.separator ""
      opts.separator "<path> : path to your branch (located in /branches)"
      #opts.separator "         Current branches: #{available_branches.join(', ')}\n"
      opts.separator "Specific options:"
      opts.on("-d", "--dry-run", "Perform a dry-run with svn (don't actually run the command)") do |e|
        options.debug = e
      end
      opts.on_tail("-h", "--help", "Show this message") do 
        puts opts
        exit
      end
      opts.on_tail("-v", "--version", "Show version") do
        puts "CollectiveX Ruby SVN tools, Version #{Collectivex::Svn.cx_version}"
        puts "Copyright, (c) 2006 CollectiveX, Inc.\n"
        exit
      end
    end
    opts.parse!(args)
    options
  end
end
