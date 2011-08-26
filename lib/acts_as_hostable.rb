module ActiveRecord
  module Acts #:nodoc:
    module Hostable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)  
      end
      
      module ClassMethods
        def acts_as_hostable(options = {})
          has_many :hostings, :as => :hostable, :dependent => :delete_all
          has_many :page_hosts, :through => :hostings

          include ActiveRecord::Acts::Hostable::InstanceMethods
        end
      end

      module InstanceMethods
        def hosts(local_site=nil)
          # Only topics & subjects have site specific hosts
          local_site = nil if ![Topic, Subject].include?(self.class)
          phs = self.page_hosts.find(:all, :conditions => {:local_site_id => local_site ? local_site.id : nil})
          phs.collect { |h| h.member }
        end

        def add_host(m, local_site=nil)
          # Only topics & subjects have site specific hosts
          local_site = nil if ![Topic, Subject].include?(self.class)
          ph = PageHost.find_or_create_by_member_id_and_local_site_id(m.id, local_site ? local_site.id : nil)
          if page_hosts.include?(ph)
            true # SSS FIXME: Return an error message instead?
          else
            g = Group.find_by_slug("host")
            g.add_member(m) unless g.nil? || m.groups.include?(g)
            page_hosts << ph 
          end
        end

        def remove_host(m, local_site=nil)
          # Only topics & subjects have site specific hosts
          local_site = nil if ![Topic, Subject].include?(self.class)
          page_hosts.delete(PageHost.find_by_member_id_and_local_site_id(m.id, local_site ? local_site.id : nil))
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Hostable)
