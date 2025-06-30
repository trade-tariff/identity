require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#page_title" do
    let(:default_title) { "UK Online Trade Tariff" }

    before do
      helper.instance_variable_set(:@content_for, {})
    end

    context "when no title is provided" do
      it "returns the default title" do
        expect(helper.page_title).to eq(default_title)
      end

      it "returns existing content_for title if set" do
        helper.content_for :title, "Existing Title"
        expect(helper.page_title).to eq("Existing Title")
      end
    end

    context "when title is provided without form object" do
      it "sets content_for to formatted title" do
        helper.page_title("Login")
        expect(helper.content_for(:title)).to eq("Login | #{default_title}")
      end
    end

    context "when title is provided with form object" do
      it "sets content_for without error prefix when form has no errors" do
        form_object = instance_double(PasswordlessForm, errors: instance_double(ActiveModel::Errors, any?: false))
        helper.page_title("Login", form_object)
        expect(helper.content_for(:title)).to eq("Login | #{default_title}")
      end

      it "sets content_for with error prefix when form has errors" do
        form_object = instance_double(PasswordlessForm, errors: instance_double(ActiveModel::Errors, any?: true))
        helper.page_title("Login", form_object)
        expect(helper.content_for(:title)).to eq("Error: Login | #{default_title}")
      end

      it "sets content_for without error prefix when form object is nil" do
        helper.page_title("Login", nil)
        expect(helper.content_for(:title)).to eq("Login | #{default_title}")
      end
    end
  end
end
