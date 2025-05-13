module Api
  class ApplicationController < ActionController::Base
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate, unless: -> { Rails.env.development? }

  private

    def authenticate
      authenticate_or_request_with_http_token do |provided_token, _options|
        api_tokens.any? { |token| ActiveSupport::SecurityUtils.secure_compare(provided_token, token) }
      end
    end

    def api_tokens
      @api_tokens ||= read_tokens
    end

    def read_tokens
      tokens = TradeTariffIdentity.api_tokens
      if tokens.present?
        tokens.split(",").map(&:strip)
      else
        []
      end
    end
  end
end
