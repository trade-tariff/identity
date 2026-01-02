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
    return :all if Rails.env.development?

    ".#{ENV['MYOTT_COOKIE_DOMAIN']}"
  end

  def api_tokens
    JSON.parse(ENV.fetch("API_TOKENS", "{}"))
  end

  def redis_config
    { url: ENV["REDIS_URL"], db: 0, id: nil }
  end

  def redis
    @redis ||= Redis.new(redis_config)
  end

  def url_with_params(url, state)
    uri = URI.parse(url)
    uri.query = URI.encode_www_form({ "state" => state })
    uri.to_s
  end
end
