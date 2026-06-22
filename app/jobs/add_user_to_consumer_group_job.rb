class AddUserToConsumerGroupJob < ApplicationJob
  queue_as :default

  def perform(email, group_name)
    CognitoServiceAdapter.new.add_to_group(email, group_name:)
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error(e)
  end
end
