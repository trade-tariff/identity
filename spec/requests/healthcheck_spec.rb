require "rails_helper"

RSpec.describe "Healthcheck", type: :request do
  describe "GET /healthcheck" do
    it "returns the app revision as git_sha1", :aggregate_failures do
      get "/healthcheck"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("git_sha1" => a_kind_of(String))
    end
  end
end
