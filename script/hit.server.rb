#! /usr/bin/env ruby

uid = "newstrust"
pwd = "thUpE2uD"
base = "http://preview.newstrust.net"
@base_cmd = "wget -q --user=#{uid} --password=#{pwd} #{base}"

@subjects_to_try = [ 'politics', 'world', 'us', 'business', 'media', 'scitech' ]
@topics_to_try   = [ 'barack_obama', 'environment', 'bush_administration', 'global_warming', 'energy', 'human_rights' ]
@sources_to_try  = [ 'new_york_times', 'chicago_tribune', 'huffington_post', 'washington_post', 'alternet' ]
@listing_types   = [ 'top_stories', 'top_rated', 'for_review' ]
@story_types     = [ 'news', 'opinion' ]
@source_types    = [ 'mainstream', 'independent' ]
@formats         = [ '', '.xml', '.json' ]

def get_it(key, cmd)
  t1 = Time.now
  system(cmd)
  t2 = Time.now
  puts "#{key}: #{t2-t1}"
end

def hit_home
  get_it("HOME", @base_cmd)
end

def fetch_landing_pages
  hit_home
  @subjects_to_try.each { |s| get_it("LANDING SUBJECT", "#{@base_cmd}/#{s}") }
  hit_home
  fetch_stories(23900..23902)
  hit_home
  @topics_to_try.each   { |t| get_it("LANDING TOPIC", "#{@base_cmd}/topics/#{t}") }
  hit_home
  fetch_stories(23903..23905)
  hit_home
end

def fetch_stories(stories)
  stories.each { |s| get_it("STORY", "#{@base_cmd}/stories/#{s}") }
  hit_home
end

def fetch(topics_to_try, prefix)
  start = 24000
  topics_to_try.each { |t|
    base = "#{@base_cmd}/#{prefix}/#{t}"
    @listing_types.each { |lt|
      fetch_landing_pages
      get_it("FULL", "#{base}/#{lt}")
      @story_types.each { |story_type|
        hit_home
        get_it("FULL STORY_TYPE", "#{base}/#{lt}/#{story_type}")
        @source_types.each { |src_type|
          @formats.each { |fmt| 
            hit_home
            get_it("FULL SRC_TYPE", "#{base}/#{lt}/#{story_type}/#{src_type}#{fmt}") 
            if (fmt == "")
              last = start + 2
              fetch_stories(start..last)
              start = last
            end
          }
        }
      }
    }
  }
end

def fetch_sources
  @sources_to_try.each { |s| get_it("SOURCE", "#{@base_cmd}/sources/#{s}") }
end

def hit_server
  puts " ######### Started at: #{Time.now} ######### "
  st = Time.now
  fetch_landing_pages
  fetch(@subjects_to_try, "subjects")
  fetch(@topics_to_try, "topics")
  fetch_sources
  fetch_landing_pages
  en = Time.now
  puts "Time taken; #{sprintf('%.1f', en-st)}; Started at #{st} and ended at #{en}"
  puts " ######### Ended at: #{Time.now} ######### "
end

if ARGV.length == 0
  puts "Usage: ruby hit_server <CMD> <OPTS>" 
  puts "Possible commands:"
  puts " spawn -- options are <N> where N is an integer for # of concurrent processes to spawn"
  puts " hit   -- hit the server!"
elsif ARGV[0] == "spawn"
  (1..ARGV[1].to_i).each { |i| system("ruby hit_server hit > hit.output.#{i} &") }
elsif ARGV[0] == "hit"
  hit_server
end
