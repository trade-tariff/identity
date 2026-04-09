class RemoveUnverifiedUsers
  def self.call
    new.call
  end

  def initialize(client: TradeTariffIdentity.cognito_client,
                 user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
                 group_id: ENV["MYOTT_ID"],
                 cutoff_time: 1.day.ago)
    @client = client
    @user_pool_id = user_pool_id
    @group_id = group_id
    @cutoff_time = cutoff_time
  end

  def call
    pagination_token = nil

    loop do
      response = client.list_users({
        user_pool_id: user_pool_id,
        pagination_token: pagination_token,
      }.compact)

      response.users.each do |user|
        next if verified?(user) || user.user_create_date > cutoff_time

        User.destroy(user.username, group_id)
      end

      pagination_token = response.pagination_token
      break unless pagination_token
    end
  end

private

  attr_reader :client, :cutoff_time, :group_id, :user_pool_id

  def verified?(user)
    user.attributes.find { |attr| attr.name == "email_verified" }&.value == "true"
  end
end
