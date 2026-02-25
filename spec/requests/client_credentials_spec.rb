require "rails_helper"

RSpec.describe "Client credentials API", type: :request do
  let(:api_tokens) { { "group1" => "12345abcde" } }
  let(:headers) { { "Authorization" => "Bearer 12345abcde", "Content-Type" => "application/json" } }

  before do
    allow(TradeTariffIdentity).to receive_messages(api_tokens: api_tokens, cognito_user_pool_id: "eu-west-2_abc123")
  end

  describe "POST /api/client_credentials" do
    let(:cognito_client) { instance_double(Aws::CognitoIdentityProvider::Client) }
    let(:create_response) do
      user_pool_client = instance_double(
        Aws::CognitoIdentityProvider::Types::UserPoolClientType,
        client_id: "cognito-client-id-123",
        client_secret: "cognito-client-secret-456",
      )
      instance_double(
        Aws::CognitoIdentityProvider::Types::CreateUserPoolClientResponse,
        user_pool_client: user_pool_client,
      )
    end

    before do
      allow(TradeTariffIdentity).to receive(:cognito_client).and_return(cognito_client)
    end

    def expected_create_params
      hash_including(
        user_pool_id: "eu-west-2_abc123",
        generate_secret: true,
        allowed_o_auth_flows: %w[client_credentials],
        allowed_o_auth_scopes: ["tariff/read", "tariff/write"],
        allowed_o_auth_flows_user_pool_client: true,
        supported_identity_providers: %w[COGNITO],
      )
    end

    context "when authenticated with valid scopes" do
      before do
        allow(cognito_client).to receive(:create_user_pool_client).and_return(create_response)
      end

      it "returns 201 Created" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(response).to have_http_status(:created)
      end

      it "returns client_id and client_secret in JSON body" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(JSON.parse(response.body)).to include(
          "client_id" => "cognito-client-id-123",
          "client_secret" => "cognito-client-secret-456",
        )
      end

      it "calls Cognito with the expected parameters" do
        post "/api/client_credentials", params: { scopes: ["tariff/read", "tariff/write"] }.to_json, headers: headers

        expect(cognito_client).to have_received(:create_user_pool_client).with(expected_create_params)
      end
    end

    context "when scopes is missing" do
      it "returns 400 Bad Request" do
        post "/api/client_credentials", params: {}.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns error message in body" do
        post "/api/client_credentials", params: {}.to_json, headers: headers

        expect(JSON.parse(response.body)["error"]).to eq("scopes is required")
      end
    end

    context "when scopes is not an array" do
      it "returns 400 Bad Request" do
        post "/api/client_credentials", params: { scopes: "tariff/read" }.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
      end

      it "returns error message in body" do
        post "/api/client_credentials", params: { scopes: "tariff/read" }.to_json, headers: headers

        expect(JSON.parse(response.body)["error"]).to eq("scopes must be an array")
      end
    end

    context "when Cognito returns InvalidParameterException" do
      before do
        allow(cognito_client).to receive(:create_user_pool_client)
          .and_raise(Aws::CognitoIdentityProvider::Errors::InvalidParameterException.new(nil, "Invalid scope"))
      end

      it "returns 422" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error message in body" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(JSON.parse(response.body)["error"]).to include("Invalid request")
      end
    end

    context "when Cognito returns ResourceNotFoundException" do
      before do
        allow(cognito_client).to receive(:create_user_pool_client)
          .and_raise(Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException.new(nil, "User pool not found"))
      end

      it "returns 404" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns error message in body" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: headers

        expect(JSON.parse(response.body)["error"]).to include("User pool not found")
      end
    end

    context "when not authenticated" do
      it "returns 401 Unauthorized" do
        post "/api/client_credentials", params: { scopes: ["tariff/read"] }.to_json, headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/client_credentials/:client_id" do
    let(:cognito_client) { instance_double(Aws::CognitoIdentityProvider::Client) }
    let(:client_id) { "cognito-client-id-123" }

    before do
      allow(TradeTariffIdentity).to receive(:cognito_client).and_return(cognito_client)
    end

    context "when authenticated and client exists" do
      before do
        allow(cognito_client).to receive(:delete_user_pool_client)
      end

      it "returns 204 No Content" do
        delete "/api/client_credentials/#{client_id}", headers: headers

        expect(response).to have_http_status(:no_content)
      end

      it "returns empty body" do
        delete "/api/client_credentials/#{client_id}", headers: headers

        expect(response.body).to be_blank
      end

      it "calls Cognito delete_user_pool_client with user_pool_id and client_id" do
        delete "/api/client_credentials/#{client_id}", headers: headers

        expect(cognito_client).to have_received(:delete_user_pool_client).with(
          user_pool_id: "eu-west-2_abc123",
          client_id: client_id,
        )
      end
    end

    context "when Cognito returns ResourceNotFoundException" do
      before do
        allow(cognito_client).to receive(:delete_user_pool_client)
          .and_raise(Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException.new(nil, "Client not found"))
      end

      it "returns 404" do
        delete "/api/client_credentials/#{client_id}", headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns error message in body" do
        delete "/api/client_credentials/#{client_id}", headers: headers

        expect(JSON.parse(response.body)["error"]).to include("App client not found")
      end
    end

    context "when not authenticated" do
      it "returns 401 Unauthorized" do
        delete "/api/client_credentials/#{client_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
