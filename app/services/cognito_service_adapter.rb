class CognitoServiceAdapter
  AuthenticationTokens = Struct.new(:id_token, :refresh_token, keyword_init: true) do
    def self.from_result(result)
      new(
        id_token: result.id_token,
        refresh_token: result.refresh_token,
      )
    end
  end

  def initialize
    @client = TradeTariffIdentity.cognito_client
    @user_pool_id = TradeTariffIdentity.cognito_user_pool_id
  end

  def find_user(username)
    @client.admin_get_user(user_pool_args(username))
  end

  def list_user_groups(username)
    @client.admin_list_groups_for_user(user_pool_args(username))
  end

  def create_user(username, email:)
    @client.admin_create_user(
      **user_pool_args(username),
      user_attributes: [{ name: "email", value: email }],
      message_action: "SUPPRESS",
    )
  end

  def add_to_group(username, group_name:)
    @client.admin_add_user_to_group(
      **user_pool_args(username),
      group_name:,
    )
  end

  def remove_from_group(username, group_name:)
    @client.admin_remove_user_from_group(
      **user_pool_args(username),
      group_name:,
    )
  end

  def delete_user(username)
    @client.admin_delete_user(user_pool_args(username))
  end

  def update_user_attributes(username, attributes)
    @client.admin_update_user_attributes(
      **user_pool_args(username),
      user_attributes: attributes,
    )
  end

  def initiate_refresh_token_auth(refresh_token)
    @client.admin_initiate_auth(
      user_pool_id: @user_pool_id,
      client_id: client_id,
      auth_flow: "REFRESH_TOKEN_AUTH",
      auth_parameters: { "REFRESH_TOKEN" => refresh_token },
    )
  end

  def refresh_tokens(refresh_token)
    if @client.respond_to?(:get_tokens_from_refresh_token)
      result = @client.get_tokens_from_refresh_token(
        client_id: client_id,
        refresh_token:,
      )

      AuthenticationTokens.from_result(result)
    end

    result = initiate_refresh_token_auth(refresh_token).authentication_result
    AuthenticationTokens.from_result(result)
  end

  def initiate_custom_auth(username)
    @client.admin_initiate_auth(
      user_pool_id: @user_pool_id,
      client_id: client_id,
      auth_flow: "CUSTOM_AUTH",
      auth_parameters: { "USERNAME" => username },
    )
  end

  def respond_to_custom_challenge(session:, username:, answer:)
    @client.respond_to_auth_challenge(
      client_id: client_id,
      challenge_name: "CUSTOM_CHALLENGE",
      session:,
      challenge_responses: {
        "USERNAME" => username,
        "ANSWER" => answer,
      },
    )
  end

  def create_user_pool_client(client_name:, scopes:)
    @client.create_user_pool_client(
      user_pool_id: @user_pool_id,
      client_name:,
      generate_secret: true,
      allowed_o_auth_flows: %w[client_credentials],
      allowed_o_auth_scopes: scopes,
      allowed_o_auth_flows_user_pool_client: true,
      supported_identity_providers: %w[COGNITO],
    )
  end

  def delete_user_pool_client(client_id:)
    @client.delete_user_pool_client(
      user_pool_id: @user_pool_id,
      client_id:,
    )
  end

  def list_users(pagination_token: nil)
    @client.list_users({ user_pool_id: @user_pool_id, pagination_token: }.compact)
  end

private

  def client_id
    TradeTariffIdentity.cognito_client_id
  end

  def user_pool_args(username)
    { user_pool_id: @user_pool_id, username: }
  end
end
