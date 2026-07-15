require "rails_helper"

RSpec.describe "Passwordless", type: :request do
  let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:consumer) { build(:consumer) }
  let(:cognito_auth_object) { Data.define(:session).new("session") }
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
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_get_user)
    end

    it "creates a new user if not found" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_create_user)
    end

    it "adds the user to the consumer's group" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_add_user_to_group).with(
        hash_including(group_name: consumer.id),
      )
    end

    it "initiates auth with auth params" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(cognito).to have_received(:admin_initiate_auth).with(
        hash_including(auth_parameters: hash_including("USERNAME" => email)),
      )
    end

    it "sets the session email" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(session[:email]).to eq(email)
    end

    it "sets the session login" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(session[:login]).to eq(cognito_auth_object.session)
    end

    it "redirects to passwordless_path" do
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(response).to redirect_to(passwordless_path)
    end

    it "redirects to login_path on Cognito service errors" do
      allow(cognito).to receive(:admin_initiate_auth).and_raise(Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "Too many requests"))
      post passwordless_path, params: { passwordless_form: { email: } }
      expect(response).to redirect_to(login_path)
    end

    it "Shows an error if the email is invalid" do
      post passwordless_path, params: { passwordless_form: { email: "invalid_email" } }
      expect(response.body).to include("Enter an email address in the correct format, like name@example.com")
    end
  end

  describe "GET /show" do
    context "when email is in session" do
      before do
        post passwordless_path, params: { passwordless_form: { email: } }
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

  describe "POST /verify" do
    context "when the code is correct" do
      let(:consumer) { build(:consumer) }
      let(:authentication_result) { Data.define(:id_token, :refresh_token).new("id_token", "refresh_token") }
      let(:cognito_auth_object) { Data.define(:authentication_result, :session).new(authentication_result, nil) }

      before do
        allow(cognito).to receive_messages(
          admin_initiate_auth: Data.define(:session).new("session"),
          respond_to_auth_challenge: cognito_auth_object,
          admin_update_user_attributes: nil,
        )
        post passwordless_path, params: { passwordless_form: { email: } }
      end

      it "responds to the auth challenge with the stored session, username, and entered code" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }

        expected_args = hash_including(session: "session", challenge_name: "CUSTOM_CHALLENGE",
                                       challenge_responses: { "USERNAME" => email, "ANSWER" => "123456" })
        expect(cognito).to have_received(:respond_to_auth_challenge).with(expected_args)
      end

      it "verifies email in Cognito" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }
        expect(cognito).to have_received(:admin_update_user_attributes)
      end

      it "sets id_token cookie" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }
        expect(cookies["id_token"]).to be_a(String)
      end

      it "sets refresh_token cookie" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }
        expect(cookies["refresh_token"]).to eq "refresh_token"
      end

      it "redirects to the consumer's success URL" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }
        expect(response).to redirect_to(consumer.success_url)
      end

      it "redirects to the consumer's success URL with the stored return URL" do
        get root_path, params: { consumer_id: consumer.id, return_to: "/subscriptions/mycommodities?as_of=2025-06-20" }
        post passwordless_path, params: { passwordless_form: { email: } }

        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }

        expect(response).to redirect_to("#{consumer.success_url}?return_to=%2Fsubscriptions%2Fmycommodities%3Fas_of%3D2025-06-20")
      end
    end

    context "when the code is wrong but a retry is still available" do
      let(:retry_response) { Data.define(:authentication_result, :session).new(nil, "new-cognito-session") }

      before do
        post passwordless_path, params: { passwordless_form: { email: } }
        allow(cognito).to receive(:respond_to_auth_challenge).and_return(retry_response)
      end

      it "re-renders the code form with an error", :aggregate_failures do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "999999" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("The code you entered is incorrect")
      end

      it "stores the new Cognito session for the next attempt" do
        post verify_passwordless_path, params: { passwordless_code_form: { code: "999999" } }
        expect(session[:login]).to eq("new-cognito-session")
      end
    end

    context "when attempts are exhausted or the code has expired" do
      it "re-renders the code form with an exhausted-attempts error", :aggregate_failures do
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(Aws::CognitoIdentityProvider::Errors::NotAuthorizedException.new(nil, "Not authorized"))
        post passwordless_path, params: { passwordless_form: { email: } }

        post verify_passwordless_path, params: { passwordless_code_form: { code: "999999" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Request a new code")
      end
    end

    context "when the submitted code is not 6 digits" do
      it "re-renders the code form with a validation error" do
        post passwordless_path, params: { passwordless_form: { email: } }

        post verify_passwordless_path, params: { passwordless_code_form: { code: "12" } }

        expect(response.body).to include("Enter the 6-digit code from your email")
      end
    end

    context "when a Cognito service error occurs" do
      it "redirects to the consumer's failure URL" do
        post passwordless_path, params: { passwordless_form: { email: } }
        allow(cognito).to receive(:respond_to_auth_challenge).and_raise(Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "Too many requests"))

        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }

        expect(response).to redirect_to(consumer.failure_url)
      end
    end

    context "when there is no passwordless session (stale or direct request)" do
      it "redirects to login_path without calling Cognito", :aggregate_failures do
        reset!
        allow(cognito).to receive(:respond_to_auth_challenge)

        post verify_passwordless_path, params: { passwordless_code_form: { code: "123456" } }

        expect(response).to redirect_to(login_path)
        expect(cognito).not_to have_received(:respond_to_auth_challenge)
      end
    end
  end

  describe "POST /resend" do
    before do
      post passwordless_path, params: { passwordless_form: { email: } }
    end

    it "re-initiates auth with the same email" do
      post resend_passwordless_path
      expect(cognito).to have_received(:admin_initiate_auth).with(
        hash_including(auth_parameters: hash_including("USERNAME" => email)),
      ).twice
    end

    it "updates the stored Cognito session" do
      allow(cognito).to receive(:admin_initiate_auth).and_return(Data.define(:session).new("resent-session"))
      post resend_passwordless_path
      expect(session[:login]).to eq("resent-session")
    end

    it "redirects back to the code entry page" do
      post resend_passwordless_path
      expect(response).to redirect_to(passwordless_path)
    end

    context "when there is no email in session" do
      it "redirects to login_path" do
        reset!
        post resend_passwordless_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when a resend was requested less than 30 seconds ago" do
      it "does not re-initiate auth a second time" do
        post resend_passwordless_path
        post resend_passwordless_path

        expect(cognito).to have_received(:admin_initiate_auth).twice # 1 from the outer create, 1 from the first resend
      end

      it "redirects with a cooldown message", :aggregate_failures do
        post resend_passwordless_path
        post resend_passwordless_path

        expect(response).to redirect_to(passwordless_path)
        follow_redirect!
        expect(response.body).to include("wait a short while")
      end
    end
  end
end
