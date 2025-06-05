module Api
  class ApplicationController < ActionController::Base
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate, unless: -> { Rails.env.development? }

  private

    def authenticate
      authenticate_or_request_with_http_token do |provided_token, _options|
        api_group_token_hash = TradeTariffIdentity.api_tokens.find do |_group, token|
          ActiveSupport::SecurityUtils.secure_compare(token, provided_token)
        end

        if api_group_token_hash
          @group = api_group_token_hash.first
          true
        else
          false
        end
      end
    end
  end
end
