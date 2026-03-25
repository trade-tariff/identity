class User
  include ActiveModel::Model

  def self.find(username, group = nil)
    cognito = CognitoServiceAdapter.new

    begin
      user_response = cognito.find_user(username)

      unless Rails.env.development?
        groups_response = cognito.list_user_groups(username)

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
    cognito = CognitoServiceAdapter.new

    begin
      unless Rails.env.development?
        cognito.remove_from_group(username, group_name: group)
      end

      if cognito.list_user_groups(username).groups.none?
        cognito.delete_user(username)
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
