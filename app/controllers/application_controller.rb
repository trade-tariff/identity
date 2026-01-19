class ApplicationController < ActionController::Base
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder

  helper_method :current_consumer

  def current_consumer
    @current_consumer ||= Consumer.load(consumer_id)
  end

  def clear_cookies
    cookies.delete(id_token_cookie_name, domain: ".#{current_consumer.cookie_domain}")
    cookies.delete(refresh_token_cookie_name, domain: ".#{current_consumer.cookie_domain}")
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
