require "rails_helper"

RSpec.describe OneTimeCodeForm, type: :model do
  describe "validations" do
    context "when code is present" do
      it "is valid" do
        form = described_class.new(code: "123456")
        expect(form).to be_valid
      end
    end

    context "when code is not present" do
      it "is invalid without a code" do
        form = described_class.new(code: nil)
        expect(form).not_to be_valid
      end

      it "adds an error for a missing code" do
        form = described_class.new(code: nil)
        form.valid?
        expect(form.errors[:code]).to include("Enter the code we sent to your email address")
      end

      it "is invalid with a blank code" do
        form = described_class.new(code: "")
        expect(form).not_to be_valid
      end
    end
  end
end
