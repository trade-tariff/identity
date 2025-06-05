require "rails_helper"

RSpec.describe User, type: :model do
  describe ".find" do
    let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
    let(:user_pool_id) { "user_pool_id" }
    let(:username) { "test_user" }
    let(:email) { "test_user@example.com" }
    let(:group) { "test_group" }

    before do
      allow(TradeTariffIdentity).to receive_messages(
        cognito_client: cognito,
        cognito_user_pool_id: user_pool_id,
      )
    end

    def build_user_attributes
      [
        instance_double(
          Aws::CognitoIdentityProvider::Types::AttributeType,
          name: "email",
          value: email,
        ),
      ]
    end

    def build_user_response(attrs = build_user_attributes)
      instance_double(
        Aws::CognitoIdentityProvider::Types::AdminGetUserResponse,
        user_attributes: attrs,
      )
    end

    def build_groups_response(group_name)
      instance_double(
        Aws::CognitoIdentityProvider::Types::AdminListGroupsForUserResponse,
        groups: [
          instance_double(
            Aws::CognitoIdentityProvider::Types::GroupType,
            group_name: group_name,
          ),
        ],
      )
    end

    context "when the user exists and is in the group" do
      subject(:find_user) { described_class.find(username, group) }

      before do
        response = build_user_response
        groups_response = build_groups_response(group)
        setup_cognito_stubs(response, groups_response)
      end

      it "returns a User object with the correct attributes" do
        expect(find_user).to have_attributes(username: username, email: email)
      end
    end

    context "when the user exists but is not in the group" do
      subject(:find_user) { described_class.find(username, group) }

      before do
        response = build_user_response
        groups_response = build_groups_response("other_group")
        setup_cognito_stubs(response, groups_response)
      end

      it "returns nil" do
        expect(find_user).to be_nil
      end
    end

    context "when the user does not exist" do
      subject(:find_user) { described_class.find(username, group) }

      before do
        expected_args = { user_pool_id: user_pool_id, username: username }
        allow(cognito).to receive(:admin_get_user)
          .with(expected_args)
          .and_raise(
            Aws::CognitoIdentityProvider::Errors::UserNotFoundException.new(nil, "User not found"),
          )
      end

      it "returns nil" do
        expect(find_user).to be_nil
      end
    end

    def setup_cognito_stubs(user_response, groups_response)
      expected_args = {
        user_pool_id: user_pool_id,
        username: username,
      }

      allow(cognito).to receive(:admin_get_user)
        .with(expected_args)
        .and_return(user_response)
      allow(cognito).to receive(:admin_list_groups_for_user)
        .with(expected_args)
        .and_return(groups_response)
    end
  end
end
