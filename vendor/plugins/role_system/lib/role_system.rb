module RoleSystem  
  class RoleRequired < StandardError; end
  class NoRolePlayer < StandardError; end
  
  def self.included(base)
    base.send :class_inheritable_array, :role_requirements, :public_actions, :private_actions
    base.send :include, InstanceMethods
    base.send :extend, ClassMethods
    base.send :role_requirements=, []
    base.send :public_actions=, []
    base.send :private_actions=, []
  end
  
  # The RoleSystem is a controller mixin to grant or restrict access to actions based on the
  # roles a user belongs to.
  #
  # First include a before_filter in the controllers you need to restrict access to.
  # I find it easier to just include this in the ApplicationController so that all 
  # subclassed controllers have access to it. In the before filter tell the role system
  # what your logged in user will be called.
  #
  #  class ApplicationController < ActionController::Base
  #    before_filter { |controller| controller.role_player = :current_user }
  #  end
  #
  #  class BlogController < ApplicationController
  #    all_access_to   :only => [:show,:index]
  #    grant_access_to :content_editor, :only => :new
  #    grant_access_to :admin,   :only => [:new, :destroy]
  #    grant_access_to :editor,  :except => :destroy
  #  end
  module ClassMethods
    
    # These actions don't require roles at all. This method is helpful for instances
    # where some actions are public, while others require a role.
    def all_access_to(options = {})
      options.assert_valid_keys(:only, :except)
      if options.has_key?(:only)
        self.public_actions = [options[:only]].flatten.compact.collect{ |a| a.to_sym }
      end
      if options.has_key?(:except)
        self.private_actions = [options[:except]].flatten.compact.collect{ |a| a.to_sym }
      end
    end
    
    # This method restricts or grants access to actions based on a user's role list.
    def grant_access_to(roles, options = {})
      roles = [roles].flatten
      options.assert_valid_keys(:if, :unless, :only, :except)
      unless (@roles_checked ||= false)
        @roles_checked = true
        before_filter :check_roles
      end

      # convert any actions into symbols
      [:only, :except].each do |key|
        if options.has_key?(key)
          options[key] = [options[key]].flatten.compact.collect{ |v| v.to_sym }
        end 
      end
      self.role_requirements||=[]
      self.role_requirements << { :roles => roles, :options => options }
    end
  end
  
  module InstanceMethods
    
    def self.included(base)
      def role_player=(param)
        @role_player = param.to_sym
      end
      
      private
      def check_roles
        return true if no_roles_required_for(binding)
        raise RoleSystem::RoleRequired unless @role_player
        user = self.send(@role_player)
        raise RoleSystem::RoleRequired unless has_required_roles?(user, binding)
        true
      rescue RoleSystem::RoleRequired, NoMethodError
        
        # restful_authentication users access_denied so if the controller already has
        # this installed then use this method.
        if self.methods.include?('access_denied')
          self.send(:access_denied)
        else
          render :nothing => true, :status => 401
        end
        false
      end

      def no_roles_required_for(binding = self.binding)
        public_action = false
        unless self.public_actions.empty?
          public_action = self.public_actions.include?(params[:action].to_sym)
        end
        unless self.private_actions.empty?
          public_action = !self.private_actions.include?(params[:action].to_sym) 
        end
        public_action
      end
      
      # This method iterates over all of the role requirements supplied by the controler
      # and determines if the account holder has the needed roles to access requested action.
      # An example role requirement array might looke like:
      #
      # [{ :roles => [:content_editor], :options => { :if => #<Proc:0x00497d5c> } }, 
      #  { :roles => [:admin], :options => { :unless => #<Proc:0x00497bb8> } }]
      #
      # The account holder is given immediate access to the controller once any role check
      # evaluates as true
      def has_required_roles?(user, binding = self.binding)
        return true unless Array===self.role_requirements
        return false if user.roles.empty?
        @access_granted = false
        self.role_requirements.each do |role_requirement|
          @failed_proc = false
          roles = role_requirement[:roles]
          options = role_requirement[:options]
          params[:action] = (params[:action]||"index").to_sym
          
          next unless access_to_action?(options)
          if options.has_key?(:if)
            
            # If the proc evaluates false then it doesn't matter if they have the required role
            # because it was only permissible during this conditional access.
            @failed_proc = true unless (String===options[:if] ? eval(options[:if], binding) : options[:if].call(params))
          end

          if options.has_key?(:unless)
            
            # If this proc evaluates true then restrict access to this action because their 
            # access was provisional for conditions where this proc would fail.
            @failed_proc = true if ( String===options[:unless] ? eval(options[:unless], binding) : options[:unless].call(params) )
          end
          
          roles.each { |role| @access_granted = true if user.has_role?(role) } unless @failed_proc
          return true if @access_granted
        end
        @access_granted
      end
      
      protected
      def access_to_action?(options)
        if options.has_key?(:only)
          return false unless options[:only].include?(params[:action])
        end
        if options.has_key?(:except)
          return false if options[:except].include?(params[:action])
        end
        true
      end
    end
  end
end