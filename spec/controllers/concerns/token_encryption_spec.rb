require "rails_helper"

RSpec.describe TokenEncryption do
  subject(:encrypt_token) { controller.send(:encrypted, "signed-token") }

  let(:controller) { Class.new { include TokenEncryption }.new }

  before do
    allow(TradeTariffIdentity).to receive(:bypass_cognito?).and_return(false)
    allow(EncryptionService).to receive(:encrypt_string).with("signed-token").and_return("encrypted-token")
  end

  context "when development uses Cognito" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "keeps the plaintext cookie expected by development consumers" do
      expect(encrypt_token).to eq("signed-token")
    end
  end

  context "when production uses Cognito" do
    before { allow(Rails.env).to receive(:development?).and_return(false) }

    it "encrypts the cookie" do
      expect(encrypt_token).to eq("encrypted-token")
    end
  end
end
