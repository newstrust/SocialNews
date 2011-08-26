module Admin::PagesHelper
  def page_name(p)
    p.split("_").map(&:capitalize) * ' '
  end

  def relative_page_path(p)
    p.split("_") * '/'
  end
end
