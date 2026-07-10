class SessionsController < ApplicationController
  include TokenEncryption

  before_action :check_consumer

  def index
    session[:consumer_id] = current_consumer.id
    session[:return_to] = safe_return_to if safe_return_to.present?
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
      redirect_to success_url, allow_other_host: true and return
    when :expired
      if refresh_session_with_token
        redirect_to success_url, allow_other_host: true and return
      end
    when :invalid
      clear_cookies
    end
  end

  def refresh_session_with_token
    return false if cookies[refresh_token_cookie_name].blank?

    begin
      tokens = TokenService.new.refresh(cookies[refresh_token_cookie_name])
      set_cookies(tokens)
      true
    rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
      clear_cookies
      false
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("Token refresh failed: #{e.full_message}")
      false
    end
  end
end
