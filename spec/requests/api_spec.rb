require "rails_helper"

RSpec.describe "Users API", type: :request do
  let(:api_tokens) { { "group1" => "12345abcde", "group2" => "other_token" } }

  before do
    allow(TradeTariffIdentity).to receive(:api_tokens).and_return(api_tokens)
  end

  describe "GET /api/users/:id" do
    let(:user) { build(:user) }
    let(:headers) { { Authorization: "Bearer 12345abcde" } }

    context "when authenticated with a valid user" do
      before do
        allow(User).to receive(:find).with(user.username, "group1").and_return(user)
      end

      it "returns a successful response" do
        get api_user_path(user.username), headers: headers
        expect(response).to have_http_status(:success)
      end

      it "returns the user details" do
        get api_user_path(user.username), headers: headers
        json_response = JSON.parse(response.body)
        expect(json_response["user"]["email"]).to eq(user.email)
      end
    end

    context "when authenticated with an invalid user" do
      before do
        allow(User).to receive(:find).and_return(nil)
      end

      it "returns an unsuccessful response" do
        get api_user_path("invalid_user"), headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns the error details" do
        get api_user_path("invalid_user"), headers: headers
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("User not found")
      end
    end

    describe "when not authenticated" do
      before do
        allow(User).to receive(:find).with(user.username).and_return(user)
      end

      it "returns an unauthorized response" do
        get api_user_path(user.username)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/users/:id" do
    let(:headers) { { Authorization: "Bearer 12345abcde" } }
    let(:username) { "test_user" }

    context "when request is successful" do
      before do
        allow(User).to receive(:destroy).with(username, "group1").and_return(true)
      end

      it "returns a successful response" do
        delete api_user_path(username), headers: headers
        expect(response).to have_http_status(:success)
      end
    end

    context "when request causes an error" do
      before do
        allow(User).to receive(:destroy).with(username, "group1").and_return(false)
      end

      it "returns an unsuccessful response" do
        delete api_user_path(username), headers: headers
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    describe "when not authenticated" do
      it "returns an unauthorized response" do
        delete api_user_path(username)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
