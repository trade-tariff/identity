require "rails_helper"

RSpec.describe User, type: :model do
  describe ".find" do
    let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
    let(:user_pool_id) { "user_pool_id" }
    let(:username) { "test_user" }
    let(:email) { "test_user@example.com" }

    before do
      allow(TradeTariffIdentity).to receive_messages(
        cognito_client: cognito,
        cognito_user_pool_id: user_pool_id,
      )
    end

    context "when the user exists" do
      let(:response) do
        instance_double(
          Aws::CognitoIdentityProvider::Types::AdminGetUserResponse,
          user_attributes: [
            instance_double(Aws::CognitoIdentityProvider::Types::AttributeType, name: "email", value: email),
          ],
        )
      end

      it "returns a User object with the correct attributes", :aggregate_failures do
        allow(cognito).to receive(:admin_get_user).with({ user_pool_id:, username: username }).and_return(response)

        user = described_class.find(username)

        expect(user).to be_a(described_class)
        expect(user.username).to eq(username)
        expect(user.email).to eq(email)
      end
    end

    context "when the user does not exist" do
      it "returns nil" do
        allow(cognito).to receive(:admin_get_user).and_raise(Aws::CognitoIdentityProvider::Errors::UserNotFoundException.new(nil, "User not found"))

        user = described_class.find(username)

        expect(user).to be_nil
      end
    end
  end
end
