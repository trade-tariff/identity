require "rails_helper"

RSpec.describe AddUserToConsumerGroupJob, type: :job do
  let(:cognito) { instance_double(CognitoServiceAdapter) }
  let(:email) { "test@email.com" }
  let(:group_name) { "consumer-id" }

  before do
    allow(CognitoServiceAdapter).to receive(:new).and_return(cognito)
    allow(cognito).to receive(:add_to_group)
  end

  it "adds the user to the consumer's group" do
    described_class.perform_now(email, group_name)

    expect(cognito).to have_received(:add_to_group).with(email, group_name:)
  end

  it "logs and swallows Cognito errors instead of raising" do
    allow(cognito).to receive(:add_to_group).and_raise(
      Aws::CognitoIdentityProvider::Errors::ServiceError.new(nil, "boom"),
    )

    expect { described_class.perform_now(email, group_name) }.not_to raise_error
  end
end
