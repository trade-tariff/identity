# frozen_string_literal: true

module TokenEncryption
  extend ActiveSupport::Concern

  private

  def encrypted(token)
    if Rails.env.development?
      token
    else
      EncryptionService.encrypt_string(token)
    end
  end
end
