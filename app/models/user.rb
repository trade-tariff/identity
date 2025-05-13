class User
  include ActiveModel::Model

  def self.find(username)
    client = TradeTariffIdentity.cognito_client
    response = client.admin_get_user({
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      username:,
    })

    User.new(username:, email: response.user_attributes.find { |attr| attr.name == "email" }&.value)
  rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
    nil
  end

  attr_accessor :username, :email
end
