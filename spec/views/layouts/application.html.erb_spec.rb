require "rails_helper"

RSpec.describe "layouts/application.html.erb", type: :view do
  it "includes govuk-footer component" do
    render
    expect(rendered).to have_css(".govuk-footer")
  end

  it "includes the feedback banner" do
    render
    expect(rendered).to have_css(".govuk-phase-banner")
  end
end
