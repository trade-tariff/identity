class RemoveUnverifiedUsersJob < ApplicationJob
  queue_as :default

  def perform
    cognito = CognitoServiceAdapter.new
    pagination_token = nil

    loop do
      response = cognito.list_users(pagination_token:)

      response.users.each do |user|
        created_at = user.user_create_date
        verified = user.attributes.find { |attr| attr.name == "email_verified" }&.value == "true"

        next if verified || created_at > 1.day.ago

        User.destroy(user.username, ENV["MYOTT_ID"])
      end

      break unless response.pagination_token

      pagination_token = response.pagination_token
    end
  end
end
