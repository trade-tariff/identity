require "rails_helper"

RSpec.describe CognitoTokenVerifier do
  describe ".issuer" do
    before do
      allow(ENV).to receive(:fetch).with("AWS_REGION").and_return("us-east-1", "eu-north-1")
      allow(ENV).to receive(:[]).with("COGNITO_USER_POOL_ID").and_return("pool-111", "pool-222")
    end

    it "reflects the current AWS_REGION and COGNITO_USER_POOL_ID env vars", :aggregate_failures do
      first_issuer = described_class.issuer
      second_issuer = described_class.issuer

      expect(first_issuer).to eq("https://cognito-idp.us-east-1.amazonaws.com/pool-111")
      expect(second_issuer).to eq("https://cognito-idp.eu-north-1.amazonaws.com/pool-222")
    end

    it "raises an error when AWS_REGION is missing" do
      allow(ENV).to receive(:fetch).with("AWS_REGION").and_raise(KeyError)

      expect { described_class.issuer }.to raise_error(KeyError)
    end

    it "raises an error when COGNITO_USER_POOL_ID is missing" do
      allow(ENV).to receive(:[]).with("COGNITO_USER_POOL_ID").and_return(nil)

      expect { described_class.issuer }.to raise_error(KeyError)
    end
  end

  describe ".jwks_url" do
    before do
      allow(ENV).to receive(:fetch).with("AWS_REGION").and_return("us-east-1", "us-west-1")
      allow(ENV).to receive(:[]).with("COGNITO_USER_POOL_ID").and_return("pool-333", "pool-444")
      allow(ENV).to receive(:[]).with("COGNITO_JWKS_BASE_URL").and_return(nil)
    end

    it "reflects the current AWS_REGION and COGNITO_USER_POOL_ID env vars", :aggregate_failures do
      first_jwks_url = described_class.jwks_url
      second_jwks_url = described_class.jwks_url

      expect(first_jwks_url).to eq("https://cognito-idp.us-east-1.amazonaws.com/pool-333/.well-known/jwks.json")
      expect(second_jwks_url).to eq("https://cognito-idp.us-west-1.amazonaws.com/pool-444/.well-known/jwks.json")
    end

    it "uses the configured key endpoint without changing the issuer", :aggregate_failures do
      allow(ENV).to receive(:[]).with("COGNITO_JWKS_BASE_URL").and_return("http://ministack:4566")
      allow(ENV).to receive(:[]).with("COGNITO_USER_POOL_ID").and_return("pool-333")

      expect(described_class.jwks_url).to eq("http://ministack:4566/pool-333/.well-known/jwks.json")
      expect(described_class.issuer).to eq("https://cognito-idp.us-east-1.amazonaws.com/pool-333")
    end

    it "raises an error when AWS_REGION is missing" do
      allow(ENV).to receive(:fetch).with("AWS_REGION").and_raise(KeyError)

      expect { described_class.jwks_url }.to raise_error(KeyError)
    end

    it "raises an error when COGNITO_USER_POOL_ID is missing" do
      allow(ENV).to receive(:[]).with("COGNITO_USER_POOL_ID").and_return(nil)

      expect { described_class.jwks_url }.to raise_error(KeyError)
    end
  end

  describe "signed local tokens" do
    let(:key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:consumer) { build(:consumer, id: "myott") }
    let(:payload) { { "sub" => "local-account", "iss" => described_class.issuer, "cognito:groups" => %w[myott], "exp" => 1.hour.from_now.to_i } }
    let(:token) { JWT.encode(payload, key, "RS256", kid: "local-key") }

    before do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(TradeTariffIdentity).to receive_messages(bypass_cognito?: false, cognito_user_pool_id: "local-pool")
      keys = { "keys" => [JWT::JWK.new(key, "local-key").export] }
      allow(Faraday).to receive(:get).with(described_class.jwks_url).and_return(
        instance_double(Faraday::Response, success?: true, body: keys.to_json),
      )
    end

    it "accepts a signed token in the consumer group" do
      expect(described_class.call(token, consumer)).to eq(:valid)
    end

    it "rejects a different signing key" do
      forged = JWT.encode(payload, OpenSSL::PKey::RSA.generate(2048), "RS256", kid: "local-key")
      expect(described_class.call(forged, consumer)).to eq(:invalid)
    end

    it "rejects the wrong issuer" do
      payload["iss"] = "https://wrong.example.test"
      expect(described_class.call(token, consumer)).to eq(:invalid)
    end

    it "rejects the wrong group" do
      payload["cognito:groups"] = %w[admin]
      expect(described_class.call(token, consumer)).to eq(:invalid)
    end

    it "rejects missing keys" do
      allow(Faraday).to receive(:get).with(described_class.jwks_url).and_return(instance_double(Faraday::Response, success?: false))
      expect(described_class.call(token, consumer)).to eq(:invalid)
    end
  end

  describe ".call" do
    let(:token) { "test-token" }
    let(:consumer) { build(:consumer, id: "myott") }
    let(:jwks_url) { described_class.jwks_url }
    let(:jwks_keys) { { "keys" => [{ "kty" => "RSA", "kid" => "test-kid", "use" => "sig" }] } }
    let(:decoded_token) { [{ "sub" => "1234567890", "email" => "test@example.com", "cognito:groups" => %w[myott] }] }

    before do
      allow(TradeTariffIdentity).to receive(:cognito_user_pool_id).and_return("test-pool")
      allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: true, body: jwks_keys.to_json))
      allow(EncryptionService).to receive(:decrypt_string).and_return(token)
      allow(JWT).to receive(:decode).and_return(decoded_token)
    end

    context "when the token is valid" do
      it "returns :valid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:valid)
      end

      it "verifies the token" do
        described_class.call(token, consumer)
        expect(JWT).to have_received(:decode).with(token, nil, true, algorithms: %w[RS256], jwks: hash_including(:keys), iss: described_class.issuer, verify_iss: true)
      end
    end

    context "when development uses local Cognito" do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(TradeTariffIdentity).to receive(:bypass_cognito?).and_return(false)
      end

      it "verifies the plaintext development token with signing keys", :aggregate_failures do
        expect(described_class.call(token, consumer)).to eq(:valid)
        expect(EncryptionService).not_to have_received(:decrypt_string)
        expect(JWT).to have_received(:decode).with(token, nil, true, algorithms: %w[RS256], jwks: hash_including(:keys), iss: described_class.issuer, verify_iss: true)
      end
    end

    context "when the token is valid but not in the expected group" do
      let(:decoded_token) { [{ "sub" => "1234567890", "email" => "test@example.com", "cognito:groups" => %w[other] }] }

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq :invalid
      end
    end

    context "when the token is blank" do
      let(:token) { nil }

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when the JWKS response is unsuccessful" do
      before do
        allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: false))
      end

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when an error occurs during token verification" do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::DecodeError)
      end

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when the token is expired" do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::ExpiredSignature)
      end

      it "returns :expired" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:expired)
      end
    end

    context "when the token cannot be decrypted" do
      before do
        allow(EncryptionService).to receive(:decrypt_string).and_raise(ActiveSupport::MessageEncryptor::InvalidMessage)
      end

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end
  end
end
