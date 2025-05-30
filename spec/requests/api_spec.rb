require "rails_helper"

RSpec.describe "Users API", type: :request do
  describe "GET /api/users/:id" do
    let(:user) { build(:user) }
    let(:headers) { { Authorization: "Bearer 12345abcde" } }

    context "when authenticated with a valid user" do
      before do
        allow(User).to receive(:find).with(user.username).and_return(user)
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
end
