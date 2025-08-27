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

  def cookie_domain
    ENV["MYOTT_COOKIE_DOMAIN"]
  end

  def api_tokens
    JSON.parse(ENV.fetch("API_TOKENS", "{}"))
  end
end
