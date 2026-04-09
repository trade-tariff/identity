module Api
  class ClientCredentialsController < Api::ApplicationController
    rescue_from Aws::CognitoIdentityProvider::Errors::ServiceError, with: :cognito_service_error
    rescue_from Aws::CognitoIdentityProvider::Errors::InvalidParameterException, with: :invalid_parameter

    def create
      scopes = params[:scopes]
      if scopes.blank?
        return render json: { error: "scopes is required" }, status: :bad_request
      end

      unless scopes.is_a?(Array)
        return render json: { error: "scopes must be an array" }, status: :bad_request
      end

      client_name = "devhub-#{Time.zone.now.to_i}"

      response = cognito.create_user_pool_client(client_name:, scopes:)

      render json: {
        client_id: response.user_pool_client.client_id,
        client_secret: response.user_pool_client.client_secret,
      }, status: :created
    rescue Aws::CognitoIdentityProvider::Errors::LimitExceededException => e
      render json: { error: "Cognito limit exceeded: #{e.message}" }, status: :service_unavailable
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException => e
      render json: { error: "User pool not found: #{e.message}" }, status: :not_found
    end

    def destroy
      client_id = params[:client_id]
      if client_id.blank?
        return render json: { error: "client_id is required" }, status: :bad_request
      end

      cognito.delete_user_pool_client(client_id:)

      head :no_content
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException => e
      render json: { error: "App client not found: #{e.message}" }, status: :not_found
    end

  private

    def invalid_parameter(exception)
      render json: { error: "Invalid request: #{exception.message}" }, status: :unprocessable_entity
    end

    def cognito_service_error(exception)
      render json: { error: "Cognito error: #{exception.message}" }, status: :bad_gateway
    end

    def cognito
      @cognito ||= CognitoServiceAdapter.new
    end
  end
end
