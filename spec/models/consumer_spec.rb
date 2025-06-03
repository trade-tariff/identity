require "rails_helper"

RSpec.describe Consumer, type: :model do
  let(:consumer_id) { "test_consumer" }
  let(:methods) { %i[method1 method2] }
  let(:consumer_attributes) do
    {
      id: consumer_id,
      methods: methods,
      success_url: "https://example.com/return",
      failure_url: "https://example.com/invalid",
      cookie_domain: "example.com",
    }
  end

  before do
    stub_const("TradeTariffIdentity::CONSUMERS", [consumer_attributes])
  end

  describe ".load" do
    context "when the consumer exists", :aggregate_failures do
      it "returns a Consumer instance with the correct attributes" do
        consumer = described_class.load(consumer_id)

        expect(consumer).to be_a(described_class)
        expect(consumer.id).to eq(consumer_id)
        expect(consumer.methods).to eq(methods)
      end

      it "returns a Consumer instance with the correct return urls" do
        consumer = described_class.load(consumer_id)

        expect(consumer.success_url).to eq("https://example.com/return")
        expect(consumer.failure_url).to eq("https://example.com/invalid")
      end
    end

    context "when the consumer does not exist" do
      it "returns nil" do
        consumer = described_class.load("non_existent_consumer")

        expect(consumer).to be_nil
      end
    end
  end

  describe "#passwordless?" do
    context "when the consumer has 'passwordless' in methods" do
      let(:methods) { %i[method1 passwordless method2] }

      it "returns true" do
        consumer = described_class.new(id: consumer_id, methods: methods)

        expect(consumer.passwordless?).to be true
      end
    end

    context "when the consumer does not have 'passwordless' in methods" do
      let(:methods) { %i[method1 method2] }

      it "returns false" do
        consumer = described_class.new(id: consumer_id, methods: methods)

        expect(consumer.passwordless?).to be false
      end
    end
  end
end
