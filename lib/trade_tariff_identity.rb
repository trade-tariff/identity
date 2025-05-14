module TradeTariffIdentity
module_function

  def cognito_client
    Aws::CognitoIdentityProvider::Client.new
  end

  def cognito_client_id
    ENV["COGNITO_CLIENT_ID"]
  end

  def cognito_user_pool_id
    ENV["COGNITO_USER_POOL_ID"]
  end

  def encryption_secret
    ENV["ENCRYPTION_SECRET"]
  end

  def api_tokens
    ENV["API_TOKENS"].to_s.split(",").map(&:strip)
  end
end
