module SocialNewsClassMethods
  module MemberValidations
    module ClassMethods
      def validates_member_can_comment
        validate do |object|
          object.errors.add_to_base "There was an error saving your comment" if object.member.nil? || !object.member.can_comment?
        end
      end
    end

    def self.included(receiver)
      receiver.extend ClassMethods
    end
  end
end

ActiveRecord::Base.send :include, SocialNewsClassMethods::MemberValidations
