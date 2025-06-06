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
      User.new(username:, email:)
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      nil
    rescue Aws::CognitoIdentityProvider::Errors::ResourceNotFoundException
      nil
    end
  end

  def self.destroy(username, group = nil)
    client = TradeTariffIdentity.cognito_client

    arguments = {
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      username: username,
    }

    begin
      unless Rails.env.development?
        client.admin_remove_user_from_group(
          arguments.merge(group_name: group),
        )
      end

      if client.admin_list_groups_for_user(arguments).groups.none?
        client.admin_delete_user(arguments)
      end

      true
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      true
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Failed to delete user: #{e.message}")
      false
    end
  end

  attr_accessor :username, :email
end
