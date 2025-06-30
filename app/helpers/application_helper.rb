module ApplicationHelper
  def page_title(title = nil, form_object = nil)
    default = "UK Online Trade Tariff"
    base_title = "#{title} | #{default}"

    if form_object&.errors&.any?
      base_title = "Error: #{base_title}"
    end

    if title
      content_for :title, base_title
    else
      content_for(:title) || default
    end
  end
end
