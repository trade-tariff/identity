require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /index" do
    context "when consumer_id is not present" do
      it "causes an error" do
        get sessions_path
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when valid consumer_id is present" do
      let(:consumer) { build(:consumer) }

      before do
        allow(Consumer).to receive(:load).with(consumer.id).and_return(consumer)
      end

      it "redirects to the login page" do
        get sessions_path, params: { consumer_id: consumer.id }
        expect(response).to redirect_to(login_path)
      end

      it "sets the consumer_id in the session" do
        get sessions_path, params: { consumer_id: consumer.id }
        expect(session[:consumer_id]).to eq(consumer.id)
      end
    end
  end

  describe "GET /new" do
    context "when consumer_id is not present" do
      it "causes an error" do
        get sessions_path
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when valid consumer_id is present" do
      let(:consumer) { build(:consumer) }

      before do
        allow(Consumer).to receive(:load).with(consumer.id).and_return(consumer)
      end

      it "returns a successful response" do
        get new_session_path, params: { consumer_id: consumer.id }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
