#!/usr/bin/env ruby

# == SVN Workflow Library for Ruby
# This SVN library was developed to aid the developer in the sometimes 
# maddening process of managing branches within a subversion repository.
# 
# The library is split into three main scripts, which are run either from trunk or 
# from your branch.
#   [branch] creates a branch when used from trunk
#   [uptrunk]  brings any new code that is in trunk into your branch.
#   [unbranch] merges changes in your branch back into trunk.
# 
# == Requirements
# The SVN Library requires the following layout of your SVN repository.
# <tt>/trunk</tt>
# <tt>/branches</tt>
# It is important that trunk and branches are siblings to one another within the 
# filesystem otherwise this library will not work.
# 
# == Usage
# 
# <b>Creating A Branch</b>
# Navigate to the trunk folder of your repository and from a command line type:
#
# <tt>ruby script/svn/branch branch_name</tt>
#
# The branch script will set a property on your root of your trunk folder
# called "svn:trunk". This property contains the revision number of trunk where you 
# branched from. This property will be used by the unbranching process to determine
# where the merge start point should be.
# 
# <b>Merging changes in trunk into your branch</b>
# Navigate to your branch directory within your respository and from a command line
# type:
#
# <tt>ruby script/svn/uptrunk</tt>
#
# Any changes in trunk since the point you branched or last ran uptrunk will be merged
# into your branch. The uptrunk branch will set a property on your root of application
# called "svn:trunk". This property contains the revision number of trunk where you 
# last imported changes from. The scripts will use this number in the future to scope
# any future merges to make sure it doesn't pull code in more than once.
# 
# <b>Merging your branch into trunk</b>
# When you branch is complete and you are ready to merge your changes into trunk,
# navigate from your branch folder to the trunk of your repository and type:
#
# <tt>ruby script/svn/unbranch branch_name</tt>
# 
# This will merge all of your changes from your branch into your trunk using the 
# previously set "svn:trunk" property as a guide.
# 
# Merging to trunk is a very sensitive task and the upmost care should be taken to ensure
# you do not overwrite another developers changes. The unbranching script offers a
# dry run flag "-d" which can be appended to the end of the command to produce a diff
# of the merge instead of merging file. If when comparing the diff you see any changes
# that you did not make then you know you will have problems with the merge. The 
# dry run can be executed like this:
# 
# <tt>ruby script/svn/unbranch branch_name -d</tt>
#
# <b>Warning</b> Do not check in "svn:trunk" property, because it will be unique to
# your branch and it may affect other users who are also using the branching tools.
# In some cases you may see conficts on the root node if this happens. When resolving
# the conflict make sure to choose your version of the "svn:trunk" property.

require 'rexml/document'
require 'ostruct'

module Collectivex
  class Svn
    include REXML
    
    attr_accessor :path
    def self.cx_version
      "0.2"
    end
    
    def version
      `svn --version`.match(/version ([\d\.]+) /)[1].to_f
    end
    
    def initialize(branch, new_branch = false, options=OpenStruct.new)
      super()      
      $stderr.puts "\n Subversion Tools \n_________________\n You can run this command manually:\n "
      @debug = options.debug
      if version < 1.3
        $stderr.puts "Sorry, this requires subversion >= 1.3.0"
        return false
      end
      
      @path = options.path || File.dirname(__FILE__) + "/../../../branches"
      @branch = branch
      if !new_branch
        if !File.exist?("#{@path}/#{@branch}")
          $stderr.puts "#{@path}/#{@branch} is not a current branch"
          @path = nil
          @branch = nil
          return false
        else
          @path = "#{@path}/#{@branch}"
        end
      else
        # new branch
        @path = nil
      end
    end

    def first_rev
      return unless @path && @branch
      xml = Document.new(`svn log #{@path} --stop-on-copy --xml`)
      xml.elements[1].elements.to_a[-1].attributes['revision']
    end
    
    def last_rev
      return unless @path && @branch
      xml = Document.new(`svn log #{@path} --stop-on-copy --xml`)
      @last_rev ||= xml.elements[1].elements[1].attributes['revision']
    end
    
    def url
      return unless @path
      xml = Document.new(`svn info #{@path} --xml`)
      xml.elements[1].elements["entry"].elements['url'].text
    end
    
    def root
      return unless @path
      xml = Document.new(`svn info #{@path} --xml`)
      xml.elements[1].elements["entry"].elements['repository'].elements['root'].text
    end
    
    def diff
      return unless @path && @branch
      svn = "svn diff -r #{first_rev}:#{last_rev} #{url}" 
      puts svn
      $stderr.puts `#{svn}` unless @debug
    end
   
    #def unbranch
    #  return unless @path && @branch
    #  svn = "svn merge #{'--dry-run ' if @debug}-r #{first_rev}:#{last_rev} #{root}/branches/#{@branch} ."
    #  puts svn
    #  $stderr.puts `#{svn}`
    #end
    
    def branch
      return if @path
      @path = File.dirname(__FILE__) + "/../../"
      svn = "svn cp -r #{last_rev} #{url} #{root}/branches/#{@branch} -m 'Creating branch for #{@branch} [#{last_rev}]'"
      puts svn
      unless @debug
        $stderr.puts `#{svn}`
        $stderr.puts `cd ../branches; svn up #{@branch}`
        $stderr.puts `svn propset svn:trunk #{last_rev} .`
      end
    end

    def head_rev
      @head_rev ||= Document.new(`svn info #{root}/trunk --xml`).elements[1].elements[1].attributes['revision']
    end

    def last_trunk
      l = `svn propget svn:trunk .`.to_i
      l = first_rev if l == 0
      l
    end

    def head_rev
      @head_rev ||= Document.new(`svn info #{root}/trunk --xml`).elements[1].elements[1].attributes['revision']
    end

    def uptrunk
      svn = "svn diff #{root}/trunk@#{last_trunk} #{root}/trunk@#{head_rev} | less"
      puts svn
      $stderr.puts `#{svn}` unless @debug
    end

    def upmerge
      svn = "svn merge #{root}/trunk@#{last_trunk} #{root}/trunk@#{head_rev}" 
      puts svn
      $stderr.puts `#{svn}` unless @debug
      $stderr.puts `svn propset svn:trunk #{head_rev} .` unless @debug
    end

    def unbranch
      return unless @path && @branch
      #puts "Did you remember to uptrunk your branch? :)"
      unbranch_diff = "unbranch_#@branch.diff"
      if @debug
        File.chmod(0644, unbranch_diff)         if File.exist?(unbranch_diff) 
        svn = "svn diff #{root}/trunk #{root}/branches/#{@branch} > #{unbranch_diff}"
      else
        svn = "svn merge #{root}/trunk #{root}/branches/#{@branch}"
      end
      puts svn
      $stderr.puts `#{svn}` 
      if @debug
        $stderr.puts "Loading diff in editor for review."
        `chmod 0444 #{unbranch_diff}; mate #{unbranch_diff}`
      else
        `svn propdel svn:trunk .`
      end
    end

  end
end
