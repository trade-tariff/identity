module Api
  class ClientCredentialsController < Api::ApplicationController
    def create
      scopes = params[:scopes]
      if scopes.blank?
        return render json: { error: "scopes is required" }, status: :bad_request
      end

      unless scopes.is_a?(Array)
        return render json: { error: "scopes must be an array" }, status: :bad_request
      end

      client = TradeTariffIdentity.cognito_client
      user_pool_id = TradeTariffIdentity.cognito_user_pool_id
      client_name = "devhub-#{Time.zone.now.to_i}"

      response = client.create_user_pool_client(
        user_pool_id:,
        client_name:,
        generate_secret: true,
        allowed_o_auth_flows: %w[client_credentials],
        allowed_o_auth_scopes: scopes,
        allowed_o_auth_flows_user_pool_client: true,
        supported_identity_providers: %w[COGNITO],
      )

      render json: {
        client_id: response.user_pool_client.client_id,
        client_secret: response.user_pool_client.client_secret,
      }, status: :created
    rescue Aws::CognitoIdentityProvider::Errors::InvalidParameterException => e
      render json: { error: "Invalid request: #{e.message}" }, status: :unprocessable_entity
    rescue Aws::CognitoIdentityProvider::Errors::LimitExceededException => e
      render json: { error: "Cognito limit exceeded: #{e.message}" }, status: :service_unavailable
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException => e
      render json: { error: "User pool not found: #{e.message}" }, status: :not_found
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      render json: { error: "Cognito error: #{e.message}" }, status: :bad_gateway
    end

    def destroy
      client_id = params[:client_id]
      if client_id.blank?
        return render json: { error: "client_id is required" }, status: :bad_request
      end

      client = TradeTariffIdentity.cognito_client
      user_pool_id = TradeTariffIdentity.cognito_user_pool_id

      client.delete_user_pool_client(
        user_pool_id:,
        client_id:,
      )

      head :no_content
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException => e
      render json: { error: "App client not found: #{e.message}" }, status: :not_found
    rescue Aws::CognitoIdentityProvider::Errors::InvalidParameterException => e
      render json: { error: "Invalid request: #{e.message}" }, status: :unprocessable_entity
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      render json: { error: "Cognito error: #{e.message}" }, status: :bad_gateway
    end
  end
end
