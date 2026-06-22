class ApplicationController < ActionController::Base
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder

  helper_method :current_consumer

  COOKIE_DURATION = 30.days.freeze

  def current_consumer
    @current_consumer ||= Consumer.load(consumer_id)
  end

  def success_url
    return current_consumer.success_url if session[:return_to].blank?

    uri = URI.parse(current_consumer.success_url)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["return_to"] = session.delete(:return_to)
    uri.query = query.to_query
    uri.to_s
  end

  def clear_cookies
    return if current_consumer.nil?

    cookies.delete(id_token_cookie_name, domain: current_consumer.cookie_domain)
    cookies.delete(refresh_token_cookie_name, domain: current_consumer.cookie_domain)
  end

  def set_cookies(tokens)
    return if tokens.blank?

    cookies[id_token_cookie_name] = {
      value: encrypted(tokens.id_token),
      httponly: true,
      domain: current_consumer.cookie_domain,
      expires: COOKIE_DURATION.from_now,
    }

    if tokens.refresh_token.present?
      cookies[refresh_token_cookie_name] = {
        value: tokens.refresh_token,
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

  def safe_return_to
    return_to = params[:return_to].to_s
    return if return_to.blank?
    # Identity only preserves relative consumer paths. The consuming app owns
    # route-level allowlisting before it follows the returned path.
    return unless return_to.start_with?("/") && !return_to.start_with?("//")

    return_to
  end

  def id_token_cookie_name
    TradeTariffIdentity.id_token_cookie_name
  end

  def refresh_token_cookie_name
    TradeTariffIdentity.refresh_token_cookie_name
  end
end
