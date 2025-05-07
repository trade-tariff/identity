require "rails_helper"

RSpec.describe "Errors", type: :request do
  around do |example|
    original_setting = Rails.application.config.consider_all_requests_local
    Rails.application.config.consider_all_requests_local = false
    example.run
    Rails.application.config.consider_all_requests_local = original_setting
  end

  describe "GET /not_found" do
    context "when html format is requested" do
      it "renders the error template with expected text" do
        get "/404", headers: { "Accept" => "text/html" }
        expect(response.body).to include("Not found")
      end

      it "responds with a 404 status" do
        get "/404", headers: { "Accept" => "text/html" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when non-html format is requested" do
      it "renders a plain text response" do
        get "/404", headers: { "Accept" => "application/json" }
        expect(response.body).to eq("Not found")
      end

      it "responds with a 404 status" do
        get "/404", headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when no format is specified" do
      it "renders the error template with expected text" do
        get "/404"
        expect(response.body).to include("Not found")
      end

      it "responds with a 404 status" do
        get "/404"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /bad_request" do
    context "when html format is requested" do
      it "renders the error template with expected text" do
        get "/400", headers: { "Accept" => "text/html" }
        expect(response.body).to include("Bad request")
      end

      it "responds with a 400 status" do
        get "/400", headers: { "Accept" => "text/html" }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when non-html format is requested" do
      it "renders a plain text response" do
        get "/400", headers: { "Accept" => "application/json" }
        expect(response.body).to eq("Bad request")
      end

      it "responds with a 404 status" do
        get "/400", headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when no format is specified" do
      it "renders the error template with expected text" do
        get "/400"
        expect(response.body).to include("Bad request")
      end

      it "responds with a 404 status" do
        get "/400"
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
