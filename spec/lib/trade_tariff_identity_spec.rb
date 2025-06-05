require "rails_helper"

RSpec.describe TradeTariffIdentity do
  describe ".api_tokens" do
    before do
      allow(ENV).to receive(:fetch).with("API_TOKENS", "{}").and_return(api_tokens_env)
    end

    context "when API_TOKENS is set" do
      let(:api_tokens_env) { '{"token1": "12345", "token2": "67890"}' }

      it "returns a hash of tokens" do
        expect(described_class.api_tokens).to eq({ "token1" => "12345", "token2" => "67890" })
      end
    end

    context "when API_TOKENS is not set" do
      let(:api_tokens_env) { "{}" }

      it "returns an empty hash" do
        expect(described_class.api_tokens).to eq({})
      end
    end
  end
end
