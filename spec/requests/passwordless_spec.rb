require "rails_helper"

RSpec.describe "Passwordless", type: :request do
  let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:consumer) { build(:consumer) }
  let(:cognito_auth_object) { Struct.new(:session).new("session") }
  let(:email) { "test@email.com" }

  before do
    allow(Consumer).to receive(:load).with(consumer.id).and_return(consumer)
    get root_path, params: { consumer_id: consumer.id }

    allow(TradeTariffIdentity).to receive(:cognito_client).and_return(cognito)
    allow(cognito).to receive(:admin_get_user).and_raise(Aws::CognitoIdentityProvider::Errors::UserNotFoundException.new(nil, "User not found"))
    allow(cognito).to receive(:admin_create_user)
    allow(cognito).to receive(:admin_add_user_to_group)
    allow(cognito).to receive(:admin_initiate_auth).and_return(cognito_auth_object)
  end

  describe "POST /create" do
    it "checks for an existing user" do
      post passwordless_path, params: { email: }
      expect(cognito).to have_received(:admin_get_user)
    end

    it "creates a new user if not found" do
      post passwordless_path, params: { email: }
      expect(cognito).to have_received(:admin_create_user)
    end

    it "adds the user to the consumer's group" do
      post passwordless_path, params: { email: }
      expect(cognito).to have_received(:admin_add_user_to_group).with(
        hash_including(group_name: consumer.id),
      )
    end

    it "initiates auth with auth params" do
      post passwordless_path, params: { email: }
      expect(cognito).to have_received(:admin_initiate_auth).with(
        hash_including(auth_parameters: hash_including("USERNAME" => email)),
      )
    end

    it "sets the session email" do
      post passwordless_path, params: { email: }
      expect(session[:email]).to eq(email)
    end

    it "sets the session login" do
      post passwordless_path, params: { email: }
      expect(session[:login]).to eq(cognito_auth_object.session)
    end

    it "redirects to passwordless_path" do
      post passwordless_path, params: { email: }
      expect(response).to redirect_to(passwordless_path)
    end

    it "redirects to login_path on error" do
      allow(cognito).to receive(:admin_initiate_auth).and_raise(StandardError.new("Error"))
      post passwordless_path, params: { email: }
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /show" do
    context "when email is in session" do
      before do
        post passwordless_path, params: { email: }
      end

      it "returns a successful response" do
        get passwordless_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when email is not in session" do
      it "redirects to login_path" do
        get passwordless_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "GET /callback" do
    context "when link is correct and used in a timely manner" do
      let(:authentication_result) { Struct.new(:id_token).new("id_token") }
      let(:cognito_auth_object) { Struct.new(:authentication_result).new(authentication_result) }

      before do
        post passwordless_path, params: { email: }

        allow(cognito).to receive(:respond_to_auth_challenge).and_return(cognito_auth_object)
        allow(cognito).to receive(:admin_update_user_attributes)
      end

      it "sets the consumer id in session" do
        allow(Consumer).to receive(:load).with("new_consumer")
        get callback_passwordless_path, params: { email:, token: "token", consumer: "new_consumer" }
        expect(session[:consumer_id]).to eq("new_consumer")
      end

      it "responds to auth challenge" do
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(cognito).to have_received(:respond_to_auth_challenge)
      end

      it "verifies email in Cognito" do
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(cognito).to have_received(:admin_update_user_attributes)
      end

      it "sets id_token cookie" do
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(cookies["id_token"]).to be_a(String)
      end

      it "redirects to the consumer's success URL" do
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(response).to redirect_to(consumer.success_url)
      end
    end

    context "when link id invalid" do
      it "redirects to the consumer's failure URL" do
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(Aws::CognitoIdentityProvider::Errors::NotAuthorizedException.new(nil, "Not authorized"))
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(response).to redirect_to(consumer.failure_url)
      end
    end

    context "when an error occurs" do
      it "redirects to the consumer's failure URL" do
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(StandardError.new("Error"))
        get callback_passwordless_path, params: { email:, token: "token" }
        expect(response).to redirect_to(consumer.failure_url)
      end
    end
  end
end
