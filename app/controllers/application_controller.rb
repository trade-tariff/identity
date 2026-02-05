class ApplicationController < ActionController::Base
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder

  helper_method :current_consumer

  COOKIE_DURATION = 30.days.freeze

  def current_consumer
    @current_consumer ||= Consumer.load(consumer_id)
  end

  def clear_cookies
    cookies.delete(id_token_cookie_name, domain: ".#{current_consumer.cookie_domain}")
    cookies.delete(refresh_token_cookie_name, domain: ".#{current_consumer.cookie_domain}")
  end

  def set_cookies(result)
    return if result.blank?

    cookies[id_token_cookie_name] = {
      value: encrypted(result.id_token),
      httponly: true,
      domain: current_consumer.cookie_domain,
      expires: COOKIE_DURATION.from_now,
    }

    if result.refresh_token.present?
      cookies[refresh_token_cookie_name] = {
        value: result.refresh_token,
        httponly: true,
        domain: current_consumer.cookie_domain,
        expires: COOKIE_DURATION.from_now,
      }
    end
  end

private

  def consumer_id
    params[:consumer_id] || session[:consumer_id]
  end

  def id_token_cookie_name
    TradeTariffIdentity.id_token_cookie_name
  end

  def refresh_token_cookie_name
    TradeTariffIdentity.refresh_token_cookie_name
  end
end
