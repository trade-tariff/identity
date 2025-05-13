require "rails_helper"

RSpec.describe "Users API", type: :request do
  describe "GET /api/users/:id" do
    context "with a valid user" do
      let(:user) { build(:user) }

      before do
        allow(User).to receive(:find).with(user.username).and_return(user)
      end

      it "returns a successful response" do
        get api_user_path(user.username)
        expect(response).to have_http_status(:success)
      end

      it "returns the user details" do
        get api_user_path(user.username)
        json_response = JSON.parse(response.body)
        expect(json_response["user"]["email"]).to eq(user.email)
      end
    end

    context "with an invalid user" do
      before do
        allow(User).to receive(:find).and_return(nil)
      end

      it "returns an unsuccessful response" do
        get api_user_path("invalid_user")
        expect(response).to have_http_status(:not_found)
      end

      it "returns the error details" do
        get api_user_path("invalid_user")
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("User not found")
      end
    end
  end
end
