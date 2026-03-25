class TokenService
  def initialize(cognito: CognitoServiceAdapter.new)
    @cognito = cognito
  end

  def refresh(refresh_token)
    @cognito.initiate_refresh_token_auth(refresh_token).authentication_result
  end

  def exchange_challenge(session:, username:, answer:)
    @cognito.respond_to_custom_challenge(
      session:,
      username:,
      answer:,
    ).authentication_result
  end

  def verify_email(username)
    @cognito.update_user_attributes(username, [{ name: "email_verified", value: "true" }])
  end
end
