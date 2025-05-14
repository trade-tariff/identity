require "rails_helper"

RSpec.describe TradeTariffIdentity do
  describe ".api_tokens" do
    before do
      allow(ENV).to receive(:[]).with("API_TOKENS").and_return(api_tokens_env)
    end

    context "when API_TOKENS is set" do
      let(:api_tokens_env) { "token1, token2, token3" }

      it "returns an array of tokens" do
        expect(described_class.api_tokens).to eq(%w[token1 token2 token3])
      end
    end

    context "when API_TOKENS is not set" do
      let(:api_tokens_env) { nil }

      it "returns an empty array" do
        expect(described_class.api_tokens).to eq([])
      end
    end

    context "when API_TOKENS contains extra spaces" do
      let(:api_tokens_env) { " token1 , token2 , token3 " }

      it "returns an array of stripped tokens" do
        expect(described_class.api_tokens).to eq(%w[token1 token2 token3])
      end
    end
  end
end
