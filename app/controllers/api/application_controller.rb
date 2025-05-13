module Api
  class ApplicationController < ActionController::Base
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate, unless: -> { Rails.env.development? }

  private

    def authenticate
      authenticate_or_request_with_http_token do |provided_token, _options|
        TradeTariffIdentity.api_tokens.any? { |token| ActiveSupport::SecurityUtils.secure_compare(provided_token, token) }
      end
    end
  end
end
