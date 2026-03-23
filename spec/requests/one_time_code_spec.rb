require "rails_helper"

RSpec.describe "OneTimeCode", type: :request do
  let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:consumer) { build(:consumer, methods: [:one_time_code]) }
  let(:cognito_auth_object) { Struct.new(:session).new("session") }
  let(:email) { "test@email.com" }

  before do
    allow(Consumer).to receive(:load).with(consumer.id).and_return(consumer)
    get root_path, params: { consumer_id: consumer.id }

    allow(TradeTariffIdentity).to receive_messages(cognito_client: cognito, otp_cognito_client_id: "otp_client_id")
    allow(cognito).to receive(:admin_get_user).and_raise(Aws::CognitoIdentityProvider::Errors::UserNotFoundException.new(nil, "User not found"))
    allow(cognito).to receive(:admin_create_user)
    allow(cognito).to receive(:admin_add_user_to_group)
    allow(cognito).to receive(:admin_initiate_auth).and_return(cognito_auth_object)
  end

  describe "POST /create" do
    it "checks for an existing user" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_get_user)
    end

    it "creates a new user if not found" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_create_user)
    end

    it "adds the user to the consumer's group" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_add_user_to_group).with(
        hash_including(group_name: consumer.id),
      )
    end

    it "initiates auth using the OTP client ID" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_initiate_auth).with(
        hash_including(client_id: "otp_client_id", auth_parameters: hash_including("USERNAME" => email)),
      )
    end

    it "sets the session otp_email" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(session[:otp_email]).to eq(email)
    end

    it "sets the session otp_login" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(session[:otp_login]).to eq(cognito_auth_object.session)
    end

    it "redirects to one_time_code_path" do
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(response).to redirect_to(one_time_code_path)
    end

    it "redirects to login_path on error" do
      allow(cognito).to receive(:admin_initiate_auth).and_raise(StandardError.new("Error"))
      post one_time_code_path, params: { passwordless_form: { email: } }
      expect(response).to redirect_to(login_path)
    end

    it "shows an error if the email is invalid" do
      post one_time_code_path, params: { passwordless_form: { email: "invalid_email" } }
      expect(response.body).to include("Enter an email address in the correct format, like name@example.com")
    end
  end

  describe "GET /show" do
    context "when otp_email is in session" do
      before do
        post one_time_code_path, params: { passwordless_form: { email: } }
      end

      it "returns a successful response" do
        get one_time_code_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when otp_email is not in session" do
      it "redirects to login_path" do
        get one_time_code_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "POST /verify" do
    context "when the code is correct and used in a timely manner" do
      let(:authentication_result) { Struct.new(:id_token, :refresh_token).new("id_token", "refresh_token") }
      let(:cognito_auth_object) { Struct.new(:authentication_result).new(authentication_result) }

      before do
        post one_time_code_path, params: { passwordless_form: { email: } }
        allow(cognito).to receive(:respond_to_auth_challenge).and_return(cognito_auth_object)
        allow(cognito).to receive(:admin_update_user_attributes)
      end

      it "responds to the auth challenge using the OTP client ID" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(cognito).to have_received(:respond_to_auth_challenge).with(
          hash_including(client_id: "otp_client_id"),
        )
      end

      it "verifies email in Cognito" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(cognito).to have_received(:admin_update_user_attributes)
      end

      it "sets id_token cookie" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(cookies["id_token"]).to be_a(String)
      end

      it "sets refresh_token cookie" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(cookies["refresh_token"]).to eq("refresh_token")
      end

      it "redirects to the consumer's success URL" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(response).to redirect_to(consumer.success_url)
      end
    end

    context "when the code is blank" do
      before do
        post one_time_code_path, params: { passwordless_form: { email: } }
      end

      it "re-renders the code entry form with an error" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "" } }
        expect(response.body).to include("Enter the code we sent to your email address")
      end
    end

    context "when the code is not authorized" do
      before do
        post one_time_code_path, params: { passwordless_form: { email: } }
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(
          Aws::CognitoIdentityProvider::Errors::NotAuthorizedException.new(nil, "Not authorized"),
        )
      end

      it "redirects to the consumer's failure URL" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "wrongcode" } }
        expect(response).to redirect_to(consumer.failure_url)
      end
    end

    context "when an error occurs" do
      before do
        post one_time_code_path, params: { passwordless_form: { email: } }
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(StandardError.new("Error"))
      end

      it "redirects to the consumer's failure URL" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(response).to redirect_to(consumer.failure_url)
      end
    end

    context "when no consumer is found" do
      it "renders the invalid page", :aggregate_failures do
        allow(Consumer).to receive(:load).with(consumer.id).and_return(nil)
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Code invalid")
      end
    end

    context "when the session has expired" do
      it "redirects to login_path" do
        post verify_one_time_code_path, params: { one_time_code_form: { code: "123456" } }
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
