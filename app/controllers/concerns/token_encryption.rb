# frozen_string_literal: true

module TokenEncryption
  extend ActiveSupport::Concern

private

  def encrypted(token)
    if TradeTariffIdentity.bypass_cognito?
      token
    else
      EncryptionService.encrypt_string(token)
    end
  end
end
