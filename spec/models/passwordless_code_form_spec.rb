require "rails_helper"

RSpec.describe PasswordlessCodeForm, type: :model do
  describe "validations" do
    context "when code is present" do
      it "is valid with a 6-digit code" do
        form = described_class.new(code: "123456")
        expect(form).to be_valid
      end

      it "is invalid with a code that is too short" do
        form = described_class.new(code: "1234")
        expect(form).not_to be_valid
      end

      it "is invalid with a non-numeric code" do
        form = described_class.new(code: "12345a")
        expect(form).not_to be_valid
      end

      it "adds an error for an incorrectly formatted code" do
        form = described_class.new(code: "abc")
        form.valid?
        expect(form.errors[:code]).to include("Enter the 6-digit code from your email")
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
        expect(form.errors[:code]).to include("Enter the 6-digit code from your email")
      end
    end
  end
end
