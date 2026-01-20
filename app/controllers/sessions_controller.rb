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
    case CognitoTokenVerifier.call(cookies[id_token_cookie_name], current_consumer)
    when :valid
      redirect_to current_consumer.success_url, allow_other_host: true and return
    when :expired
      if refresh_session_with_token
        redirect_to current_consumer.success_url, allow_other_host: true and return
      end
    when :invalid
      clear_cookies
    end
  end

  def refresh_session_with_token
    return false if cookies[refresh_token_cookie_name].blank?

    begin
      client = TradeTariffIdentity.cognito_client

      response = client.admin_initiate_auth(
        user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
        client_id: TradeTariffIdentity.cognito_client_id,
        auth_flow: "REFRESH_TOKEN_AUTH",
        auth_parameters: {
          "REFRESH_TOKEN" => cookies[refresh_token_cookie_name],
        },
      )

      cookies[id_token_cookie_name] = {
        value: encrypted(response.authentication_result.id_token),
        httponly: true,
        domain: current_consumer.cookie_domain,
        expires: 1.day.from_now,
      }

      if response.authentication_result.refresh_token.present?
        cookies[refresh_token_cookie_name] = {
          value: response.authentication_result.refresh_token,
          httponly: true,
          domain: current_consumer.cookie_domain,
          expires: 30.days.from_now,
        }
      end

      true
    rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
      clear_cookies
      false
    rescue StandardError => e
      Rails.logger.error("Token refresh failed: #{e.message}")
      false
    end
  end

  def id_token_cookie_name
    TradeTariffIdentity.id_token_cookie_name
  end

  def refresh_token_cookie_name
    TradeTariffIdentity.refresh_token_cookie_name
  end
end
