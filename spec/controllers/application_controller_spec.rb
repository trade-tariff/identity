require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  describe "#clear_cookies" do
    let(:consumer) { build(:consumer, cookie_domain: ".example.com") }
    let(:deleted_domains) { [] }

    before do
      controller.instance_variable_set(:@current_consumer, consumer)
      allow(controller).to receive(:cookies).and_wrap_original do |original|
        jar = original.call
        allow(jar).to receive(:delete) { |_name, opts| deleted_domains << opts[:domain] }
        jar
      end

      controller.clear_cookies
    end

    it "deletes cookies using the exact domain they were set on" do
      expect(deleted_domains).to all(eq(consumer.cookie_domain))
    end
  end
end
