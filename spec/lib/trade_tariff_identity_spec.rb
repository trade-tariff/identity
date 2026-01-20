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

  describe ".id_token_cookie_name" do
    before do
      ENV["ENVIRONMENT"] = environment
    end

    after do
      ENV.delete("ENVIRONMENT")
    end

    context "when environment is production" do
      let(:environment) { "production" }

      it "returns id_token" do
        expect(described_class.id_token_cookie_name).to eq("id_token")
      end
    end

    context "when environment is staging" do
      let(:environment) { "staging" }

      it "returns staging_id_token" do
        expect(described_class.id_token_cookie_name).to eq("staging_id_token")
      end
    end

    context "when environment is development" do
      let(:environment) { "development" }

      it "returns development_id_token" do
        expect(described_class.id_token_cookie_name).to eq("development_id_token")
      end
    end
  end

  describe ".refresh_token_cookie_name" do
    before do
      allow(ENV).to receive(:fetch).with("ENVIRONMENT", "production").and_return(environment)
    end

    context "when environment is production" do
      let(:environment) { "production" }

      it "returns refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq("refresh_token")
      end
    end

    context "when environment is staging" do
      let(:environment) { "staging" }

      it "returns staging_refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq("staging_refresh_token")
      end
    end

    context "when environment is development" do
      let(:environment) { "development" }

      it "returns development_refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq("development_refresh_token")
      end
    end
  end
end
