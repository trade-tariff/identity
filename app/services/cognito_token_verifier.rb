class CognitoTokenVerifier
  def self.issuer
    region = ENV.fetch("AWS_REGION")
    user_pool_id = TradeTariffIdentity.cognito_user_pool_id
    raise KeyError, "key not found: COGNITO_USER_POOL_ID" unless user_pool_id

    "https://cognito-idp.#{region}.amazonaws.com/#{user_pool_id}"
  end

  def self.jwks_url
    # Development only: outside development, keys always come from the AWS issuer.
    base_url = ENV["COGNITO_JWKS_BASE_URL"] if Rails.env.development?
    return "#{base_url}/#{TradeTariffIdentity.cognito_user_pool_id}/.well-known/jwks.json" if base_url.present?

    "#{issuer}/.well-known/jwks.json"
  end

  def self.call(token, consumer)
    new(token, consumer).call
  end

  def initialize(token, consumer)
    @token = token
    @consumer = consumer
  end

  def call
    return :invalid if token.blank? || consumer.blank?
    return :invalid if jwks_keys.nil? && !TradeTariffIdentity.bypass_cognito?

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
    return token if Rails.env.development? || TradeTariffIdentity.bypass_cognito?

    EncryptionService.decrypt_string(token)
  end

  def decode_jwt_token(token_to_decode)
    if TradeTariffIdentity.bypass_cognito?
      JWT.decode(token_to_decode, nil, false)
    else
      JWT.decode(token_to_decode, nil, true,
                 algorithms: %w[RS256],
                 jwks: { keys: jwks_keys },
                 iss: self.class.issuer,
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
    url = self.class.jwks_url
    Rails.cache.fetch("cognito_jwks_keys:#{url}", expires_in: 1.hour) do
      response = Faraday.get(url)
      JSON.parse(response.body)["keys"] if response.success?
    end
  end
end
