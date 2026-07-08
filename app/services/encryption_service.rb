class EncryptionService
  def self.encrypt_string(string)
    encryptor.encrypt_and_sign(string)
  end

  def self.decrypt_string(encrypted_string)
    encryptor.decrypt_and_verify(encrypted_string)
  end

  def self.encryptor
    @encryptor ||= begin
      key = ActiveSupport::KeyGenerator
              .new(TradeTariffIdentity.encryption_secret)
              .generate_key("identity_token_encryption_v1", 32)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
