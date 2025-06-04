class User
  include ActiveModel::Model

  def self.find(username, group = nil)
    client = TradeTariffIdentity.cognito_client

    begin
      arguments = {
        user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
        username: username,
      }

      user_response = client.admin_get_user(arguments)

      unless Rails.env.development?
        groups_response = client.admin_list_groups_for_user(arguments)

        in_group = groups_response.groups.any? { |g| g.group_name == group }
        return nil unless in_group
      end

      email = user_response.user_attributes.find { |attr| attr.name == "email" }&.value
      User.new(username: username, email: email)
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      nil
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException
      nil
    end
  end

  attr_accessor :username, :email
end
