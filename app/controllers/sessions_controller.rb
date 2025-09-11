class SessionsController < ApplicationController
  include TokenEncryption

  before_action :check_consumer

  def index
    session[:consumer_id] = current_consumer.id
    redirect_to login_path
  end

  def new
    check_session

    if current_consumer.passwordless?
      @passwordless = PasswordlessForm.new
    end
  end

private

  def check_consumer
    redirect_to "/400" and return if current_consumer.nil?
  end

  def check_session
    case CognitoTokenVerifier.call(cookies[:id_token], current_consumer)
    when :valid
      redirect_to current_consumer.success_url, allow_other_host: true and return
    when :expired
      if refresh_session_with_token
        redirect_to current_consumer.success_url, allow_other_host: true and return
      end
    end
  end

  def refresh_session_with_token
    return false if cookies[:refresh_token].blank?

    begin
      client = TradeTariffIdentity.cognito_client

      response = client.admin_initiate_auth(
        user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
        client_id: TradeTariffIdentity.cognito_client_id,
        auth_flow: "REFRESH_TOKEN_AUTH",
        auth_parameters: {
          "REFRESH_TOKEN" => cookies[:refresh_token],
        },
      )

      cookies[:id_token] = {
        value: encrypted(response.authentication_result.id_token),
        httponly: true,
        domain: current_consumer.cookie_domain,
        expires: 1.day.from_now,
      }

      if response.authentication_result.refresh_token.present?
        cookies[:refresh_token] = {
          value: response.authentication_result.refresh_token,
          httponly: true,
          domain: current_consumer.cookie_domain,
          expires: 30.days.from_now,
        }
      end

      true
    rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
      cookies.delete(:id_token, domain: ".#{current_consumer.cookie_domain}")
      cookies.delete(:refresh_token, domain: ".#{current_consumer.cookie_domain}")
      false
    rescue StandardError => e
      Rails.logger.error("Token refresh failed: #{e.message}")
      false
    end
  end
end
