require "rails_helper"

RSpec.describe RemoveUnverifiedUsers do
  def stub_list_users_response(users:, pagination_token: nil)
    instance_double(
      Aws::CognitoIdentityProvider::Types::ListUsersResponse,
      users: users,
      pagination_token: pagination_token,
    )
  end

  def build_user(age:, username:, email_verified:)
    instance_double(
      Aws::CognitoIdentityProvider::Types::UserType,
      user_create_date: age,
      username: username,
      attributes: [
        instance_double(
          Aws::CognitoIdentityProvider::Types::AttributeType,
          name: "email_verified",
          value: email_verified,
        ),
      ],
    )
  end

  subject(:service) do
    described_class.new(
      client: client,
      user_pool_id: user_pool_id,
      group_id: group_id,
      cutoff_time: cutoff_time,
    )
  end

  let(:client) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:user_pool_id) { "test-pool" }
  let(:group_id) { "myott" }
  let(:cutoff_time) { 1.day.ago }

  before do
    allow(User).to receive(:destroy)
  end

  context "when the user is older than one day and unverified" do
    before do
      allow(client).to receive(:list_users).and_return(
        stub_list_users_response(
          users: [build_user(age: 2.days.ago, username: "old_unverified", email_verified: "false")],
        ),
      )

      service.call
    end

    it "deletes the user" do
      expect(User).to have_received(:destroy).with("old_unverified", "myott").once
    end
  end

  context "when the user is old but verified" do
    before do
      allow(client).to receive(:list_users).and_return(
        stub_list_users_response(
          users: [build_user(age: 2.days.ago, username: "old_verified", email_verified: "true")],
        ),
      )

      service.call
    end

    it "does not delete the user" do
      expect(User).not_to have_received(:destroy)
    end
  end

  context "when the user is new and unverified" do
    before do
      allow(client).to receive(:list_users).and_return(
        stub_list_users_response(
          users: [build_user(age: 6.hours.ago, username: "new_unverified", email_verified: "false")],
        ),
      )

      service.call
    end

    it "does not delete the user" do
      expect(User).not_to have_received(:destroy)
    end
  end

  context "when Cognito returns multiple pages" do
    before do
      allow(client).to receive(:list_users).and_return(
        stub_list_users_response(
          users: [build_user(age: 2.days.ago, username: "old_unverified_1", email_verified: "false")],
          pagination_token: "next-token",
        ),
        stub_list_users_response(
          users: [build_user(age: 2.days.ago, username: "old_unverified_2", email_verified: "false")],
        ),
      )

      service.call
    end

    it "deletes users across pages", :aggregate_failures do
      expect(User).to have_received(:destroy).with("old_unverified_1", "myott").once
      expect(User).to have_received(:destroy).with("old_unverified_2", "myott").once
    end
  end
end
