class RemoveUnverifiedUsers
  def self.call
    new.call
  end

  def initialize(adapter: CognitoServiceAdapter.new,
                 group_id: ENV["MYOTT_ID"],
                 cutoff_time: 1.day.ago)
    @adapter = adapter
    @group_id = group_id
    @cutoff_time = cutoff_time
  end

  def call
    pagination_token = nil

    loop do
      response = adapter.list_users(pagination_token: pagination_token)

      response.users.each do |user|
        next if verified?(user) || user.user_create_date > cutoff_time

        # Deliberately unrescued. A refused deletion means this user is still
        # here, and throttling refuses every following call too, so continuing
        # the sweep only burns more throttled calls and hides the failure. The
        # task is idempotent and runs daily, so aborting costs one night.
        User.destroy(user.username, group_id)
      end

      pagination_token = response.pagination_token
      break unless pagination_token
    end
  end

private

  attr_reader :adapter, :cutoff_time, :group_id

  def verified?(user)
    user.attributes.find { |attr| attr.name == "email_verified" }&.value == "true"
  end
end
