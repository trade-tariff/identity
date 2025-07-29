require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /index" do
    context "when consumer_id is not present" do
      it "causes an error" do
        get sessions_path
        expect(response).to redirect_to("/400")
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
        expect(response).to redirect_to("/400")
      end
    end

    context "when valid consumer_id is present" do
      let(:consumer) { build(:consumer, success_url:) }
      let(:success_url) { "http://example.com/success" }
      let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client, admin_initiate_auth: cognito_auth_object) }
      let(:authentication_result) { Struct.new(:id_token, :refresh_token).new("id_token", "refresh_token") }
      let(:cognito_auth_object) { Struct.new(:authentication_result).new(authentication_result) }

      before do
        allow(Consumer).to receive(:load).with(consumer.id).and_return(consumer)

        allow(TradeTariffIdentity).to receive(:cognito_client).and_return(cognito)

        cookies[:refresh_token] = "some_refresh_token_value"
        cookies[:id_token] = "some_id_token_value"
      end

      it "redirects to the consumer's success URL when session is valid" do
        allow(CognitoTokenVerifier).to receive(:call).and_return(:valid)
        get new_session_path, params: { consumer_id: consumer.id }
        expect(response).to redirect_to(success_url)
      end

      it "refreshes the session and redirects to the consumer's success URL when existing session is expired" do
        allow(CognitoTokenVerifier).to receive(:call).and_return(:expired)
        get new_session_path, params: { consumer_id: consumer.id }
        expect(response).to redirect_to(success_url)
      end

      it "returns a successful response when there is no valid or expired session" do
        cookies[:refresh_token] = nil
        cookies[:id_token] = nil
        get new_session_path, params: { consumer_id: consumer.id }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
