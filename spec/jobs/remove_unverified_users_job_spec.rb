require "rails_helper"

describe RemoveUnverifiedUsersJob do
  def setup_response(age, username, email_verified, pagination_token = nil)
    allow(client).to receive_messages(
      list_users: instance_double(Aws::CognitoIdentityProvider::Types::ListUsersResponse, users: [instance_double(Aws::CognitoIdentityProvider::Types::UserType, user_create_date: age, username:, attributes: [instance_double(Aws::CognitoIdentityProvider::Types::AttributeType, name: "email_verified", value: email_verified)])], pagination_token:),
      admin_delete_user: nil,
    )
  end

  let(:client) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:user_pool_id) { "test-pool" }

  before do
    allow(TradeTariffIdentity).to receive_messages(cognito_client: client, cognito_user_pool_id: user_pool_id)
  end

  it "deletes only users older than 1 day with unverified email (old_unverified)" do
    setup_response(2.days.ago, "old_unverified", "false")
    described_class.perform_now
    expect(client).to have_received(:admin_delete_user).with(hash_including(username: "old_unverified")).once
  end

  it "does not delete users if old but verified" do
    setup_response(2.days.ago, "old_verified", "true")
    described_class.perform_now
    expect(client).not_to have_received(:admin_delete_user)
  end

  it "does not delete users if new and unverified" do
    setup_response(6.hours.ago, "new_unverified", "false")
    described_class.perform_now
    expect(client).not_to have_received(:admin_delete_user)
  end

  it "handles pagination and deletes users across multiple pages", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    first_page_users = [
      instance_double(Aws::CognitoIdentityProvider::Types::UserType, user_create_date: 2.days.ago, username: "old_unverified_1", attributes: [instance_double(Aws::CognitoIdentityProvider::Types::AttributeType, name: "email_verified", value: "false")]),
    ]
    second_page_users = [
      instance_double(Aws::CognitoIdentityProvider::Types::UserType, user_create_date: 2.days.ago, username: "old_unverified_2", attributes: [instance_double(Aws::CognitoIdentityProvider::Types::AttributeType, name: "email_verified", value: "false")]),
    ]

    allow(client).to receive(:list_users).and_return(
      instance_double(Aws::CognitoIdentityProvider::Types::ListUsersResponse, users: first_page_users, pagination_token: "next-token"),
      instance_double(Aws::CognitoIdentityProvider::Types::ListUsersResponse, users: second_page_users, pagination_token: nil),
    )
    allow(client).to receive(:admin_delete_user)

    described_class.perform_now

    expect(client).to have_received(:admin_delete_user).with(hash_including(username: "old_unverified_1")).once
    expect(client).to have_received(:admin_delete_user).with(hash_including(username: "old_unverified_2")).once
  end
end
