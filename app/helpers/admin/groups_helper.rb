module Admin::GroupsHelper
  def common_group_fieldset(form_obj, group, attrs)
    attrs.inject("") { |buf, attr| buf + form_field(form_obj, attr) }
  end

  def social_group_fieldset(form_obj, group, attrs)
    fields_for :social_group_attributes, group.sg_attrs do |sgf|
      attrs.inject("") { |buf, attr| buf + form_field(sgf, attr) }
    end
  end
end
