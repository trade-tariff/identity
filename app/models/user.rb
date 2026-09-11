class User
  include ActiveModel::Model

  def self.find(username, group = nil)
    cognito = CognitoServiceAdapter.new

    begin
      user_response = cognito.find_user(username)

      unless TradeTariffIdentity.bypass_cognito?
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

  # Raised when Cognito refuses a deletion and the user is therefore still
  # present. Callers must not be able to mistake that for a completed deletion.
  class DeletionError < StandardError; end

  def self.destroy(username, group = nil)
    cognito = CognitoServiceAdapter.new

    begin
      unless TradeTariffIdentity.bypass_cognito?
        cognito.remove_from_group(username, group_name: group)
      end

      if cognito.list_user_groups(username).groups.none?
        cognito.delete_user(username)
      end

      true
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      # The user being absent is the state the caller asked for, so this is a
      # success. It is the only AWS error that means the deletion need not happen.
      true
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      # Everything else leaves the user in place. TooManyRequestsException is the
      # one that bites during the nightly sweep: returning false here let each
      # throttled deletion pass for a completed one, so the sweep finished green
      # and the accounts stayed. Raising makes the failed deletion visible and
      # lets the caller decide whether to retry.
      raise DeletionError, "Cognito refused deletion of #{username}: #{e.message}"
    end
  end

  attr_accessor :username, :email
end
