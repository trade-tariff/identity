class CognitoTokenVerifier
  ISSUER = "https://cognito-idp.#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['COGNITO_USER_POOL_ID']}".freeze
  JWKS_URL = "#{ISSUER}/.well-known/jwks.json".freeze

  def self.verify_id_token(token, consumer)
    return :invalid if token.blank? || consumer.blank?
    return :invalid if jwks_keys.nil? && !Rails.env.development?

    new(token, consumer).verify
    :valid
  rescue JWT::ExpiredSignature
    :expired
  rescue JWT::DecodeError
    :invalid
  end

  def self.jwks_keys
    Rails.cache.fetch("cognito_jwks_keys", expires_in: 1.hour) do
      response = Faraday.get(JWKS_URL)
      JSON.parse(response.body)["keys"] if response.success?
    end
  end

  attr_accessor :token, :consumer

  def initialize(token, consumer)
    @token = token
    @consumer = consumer
  end

  def verify
    verified = decrypt.decode.token[0]
    in_group?(verified) ? verified : nil
  end

  def decrypt
    unless Rails.env.development?
      self.token = EncryptionService.decrypt_string(@encrypted_token)
    end
    self
  end

  def decode
    self.token = if Rails.env.development?
                   JWT.decode(token, nil, false)
                 else
                   JWT.decode(token, nil, true,
                              algorithms: %w[RS256],
                              jwks: { keys: CognitoTokenVerifier.jwks_keys },
                              iss: ISSUER,
                              verify_iss: true)
                 end
    self
  end

  def in_group?(token)
    groups = token["cognito:groups"] || []
    groups.include?(consumer.id)
  end
end
