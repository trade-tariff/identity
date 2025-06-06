require "rails_helper"

RSpec.describe User, type: :model do
  def build_groups_response(group_name)
    groups = if group_name
               [
                 instance_double(
                   Aws::CognitoIdentityProvider::Types::GroupType,
                   group_name: group_name,
                 ),
               ]
             else
               []
             end

    instance_double(
      Aws::CognitoIdentityProvider::Types::AdminListGroupsForUserResponse,
      groups: groups,
    )
  end

  let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:user_pool_id) { "user_pool_id" }
  let(:username) { "test_user" }
  let(:group) { "test_group" }

  before do
    allow(TradeTariffIdentity).to receive_messages(
      cognito_client: cognito,
      cognito_user_pool_id: user_pool_id,
    )
  end

  describe ".find" do
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

    let(:email) { "test_user@example.com" }

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
  end

  describe ".destroy" do
    subject(:destroy_user) { described_class.destroy(username, group) }

    def setup_cognito_stubs(other_group)
      expected_args = {
        user_pool_id: user_pool_id,
        username: username,
      }

      allow(cognito).to receive(:admin_delete_user)
        .with(expected_args)
      allow(cognito).to receive(:admin_list_groups_for_user)
        .with(expected_args)
        .and_return(build_groups_response(other_group))
      allow(cognito).to receive(:admin_remove_user_from_group)
        .with(expected_args.merge(group_name: group))
    end

    context "when the user exists and is only in this group" do
      before do
        setup_cognito_stubs(nil)
      end

      it "removes the user from the group" do
        destroy_user
        expect(cognito).to have_received(:admin_remove_user_from_group)
          .with(hash_including(group_name: group))
      end

      it "deletes the user" do
        destroy_user
        expect(cognito).to have_received(:admin_delete_user)
          .with(hash_including(username: username))
      end

      it "returns true after successfully removing the user from the group and deleting the user" do
        expect(destroy_user).to be true
      end
    end

    context "when the user exists and is also in another group" do
      before do
        setup_cognito_stubs("other_group")
      end

      it "removes the user from the group" do
        destroy_user
        expect(cognito).to have_received(:admin_remove_user_from_group)
          .with(hash_including(group_name: group))
      end

      it "does not delete the user" do
        destroy_user
        expect(cognito).not_to have_received(:admin_delete_user)
      end

      it "returns true" do
        expect(destroy_user).to be true
      end
    end

    context "when the user does not exist" do
      before do
        setup_cognito_stubs(nil)
        allow(cognito).to receive(:admin_list_groups_for_user)
          .and_raise(
            Aws::CognitoIdentityProvider::Errors::UserNotFoundException.new(nil, "User not found"),
          )
      end

      it "returns true without performing any actions" do
        expect(destroy_user).to be true
      end
    end

    context "when a service error occurs during deletion" do
      before do
        allow(cognito).to receive(:admin_list_groups_for_user)
          .and_return(build_groups_response(group))
        allow(cognito).to receive(:admin_remove_user_from_group)
          .and_raise(
            Aws::CognitoIdentityProvider::Errors::ServiceError.new(nil, "Service error"),
          )
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        destroy_user
        expect(Rails.logger).to have_received(:error).with(/Failed to delete user/)
      end

      it "returns false" do
        expect(destroy_user).to be false
      end
    end
  end
end
