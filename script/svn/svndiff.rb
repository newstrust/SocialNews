#!/usr/bin/env ruby
#svndiff

diff = `svn diff #{ARGV}`

diff.split("\n").each do |line|
  $stdout.puts line.sub(/^\+/,"\e[2;32;2m+").sub(/^\-/,"\e[2;31;2m-") + "\e[0;36;0m\n"
end
