class CognitoTokenVerifier
  ISSUER = "https://cognito-idp.#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['COGNITO_USER_POOL_ID']}".freeze
  JWKS_URL = "#{ISSUER}/.well-known/jwks.json".freeze

  def self.call(token, consumer)
    new(token, consumer).call
  end

  def initialize(token, consumer)
    @token = token
    @consumer = consumer
  end

  def call
    return :invalid if token.blank? || consumer.blank?
    return :invalid if jwks_keys.nil? && !Rails.env.development?

    decoded_token = decode_and_verify_token
    user_in_authorized_group?(decoded_token) ? :valid : :invalid
  rescue JWT::ExpiredSignature
    :expired
  rescue JWT::DecodeError, ActiveSupport::MessageEncryptor::InvalidMessage
    :invalid
  end

private

  attr_reader :token, :consumer

  def decode_and_verify_token
    decrypted_token = decrypt_token_if_needed
    decoded_token_array = decode_jwt_token(decrypted_token)
    decoded_token_array[0] # JWT.decode returns an array, we want the payload
  end

  def decrypt_token_if_needed
    return token if Rails.env.development?

    EncryptionService.decrypt_string(token)
  end

  def decode_jwt_token(token_to_decode)
    if Rails.env.development?
      JWT.decode(token_to_decode, nil, false)
    else
      JWT.decode(token_to_decode, nil, true,
                 algorithms: %w[RS256],
                 jwks: { keys: jwks_keys },
                 iss: ISSUER,
                 verify_iss: true)
    end
  end

  def user_in_authorized_group?(decoded_token)
    groups = decoded_token["cognito:groups"] || []
    groups.include?(consumer.id)
  end

  def jwks_keys
    @jwks_keys ||= fetch_jwks_keys
  end

  def fetch_jwks_keys
    Rails.cache.fetch("cognito_jwks_keys", expires_in: 1.hour) do
      response = Faraday.get(JWKS_URL)
      JSON.parse(response.body)["keys"] if response.success?
    end
  end
end
