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

      it "returns :id_token" do
        expect(described_class.id_token_cookie_name).to eq(:id_token)
      end
    end

    context "when environment is staging" do
      let(:environment) { "staging" }

      it "returns :staging_id_token" do
        expect(described_class.id_token_cookie_name).to eq(:staging_id_token)
      end
    end

    context "when environment is development" do
      let(:environment) { "development" }

      it "returns :development_id_token" do
        expect(described_class.id_token_cookie_name).to eq(:development_id_token)
      end
    end
  end

  describe ".bypass_cognito?" do
    context "when Rails.env is development" do
      before { allow(Rails.env).to receive(:development?).and_return(true) }

      it "returns true regardless of BYPASS_COGNITO" do
        expect(described_class.bypass_cognito?).to be(true)
      end
    end

    context 'when Rails.env is not development and BYPASS_COGNITO is "true"' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        ENV["BYPASS_COGNITO"] = "true"
      end

      after { ENV.delete("BYPASS_COGNITO") }

      it "returns true" do
        expect(described_class.bypass_cognito?).to be(true)
      end
    end

    context 'when Rails.env is not development and BYPASS_COGNITO is set to a value other than "true"' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        ENV["BYPASS_COGNITO"] = "1"
      end

      after { ENV.delete("BYPASS_COGNITO") }

      it "returns false" do
        expect(described_class.bypass_cognito?).to be(false)
      end
    end

    context "when Rails.env is not development and BYPASS_COGNITO is not set" do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        ENV.delete("BYPASS_COGNITO")
      end

      it "returns false" do
        expect(described_class.bypass_cognito?).to be(false)
      end
    end
  end

  describe ".refresh_token_cookie_name" do
    before do
      allow(ENV).to receive(:fetch).with("ENVIRONMENT", "production").and_return(environment)
    end

    context "when environment is production" do
      let(:environment) { "production" }

      it "returns :refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq(:refresh_token)
      end
    end

    context "when environment is staging" do
      let(:environment) { "staging" }

      it "returns :staging_refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq(:staging_refresh_token)
      end
    end

    context "when environment is development" do
      let(:environment) { "development" }

      it "returns :development_refresh_token" do
        expect(described_class.refresh_token_cookie_name).to eq(:development_refresh_token)
      end
    end
  end
end
