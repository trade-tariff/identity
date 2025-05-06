require "rails_helper"

RSpec.describe Consumer, type: :model do
  let(:consumer_id) { "test_consumer" }
  let(:methods) { %i[method1 method2] }
  let(:consumer_attributes) do
    {
      id: consumer_id,
      methods: methods,
      return_url: "https://example.com/return",
      cookie_domain: "example.com",
    }
  end

  before do
    stub_const("TradeTariffIdentity::CONSUMERS", [consumer_attributes])
  end

  describe ".load" do
    context "when the consumer exists" do
      # rubocop:disable RSpec/MultipleExpectations
      it "returns a Consumer instance with the correct attributes" do
        consumer = described_class.load(consumer_id)

        expect(consumer).to be_a(described_class)
        expect(consumer.id).to eq(consumer_id)
        expect(consumer.methods).to eq(methods)
      end
      # rubocop:enable RSpec/MultipleExpectations
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
