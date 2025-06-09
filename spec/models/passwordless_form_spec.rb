require "rails_helper"

RSpec.describe PasswordlessForm, type: :model do
  describe "validations" do
    context "when email is present" do
      it "is valid with a correctly formatted email" do
        form = described_class.new(email: "test@example.com")
        expect(form).to be_valid
      end

      it "is invalid with an incorrectly formatted email" do
        form = described_class.new(email: "invalid-email")
        expect(form).not_to be_valid
      end

      it "adds an error for an incorrectly formatted email" do
        form = described_class.new(email: "invalid-email")
        form.valid?
        expect(form.errors[:email]).to include("Enter an email address in the correct format, like name@example.com")
      end
    end

    context "when email is not present" do
      it "is invalid without an email" do
        form = described_class.new(email: nil)
        expect(form).not_to be_valid
      end

      it "adds an error for a missing email" do
        form = described_class.new(email: nil)
        form.valid?
        expect(form.errors[:email]).to include("Enter an email address in the correct format, like name@example.com")
      end
    end
  end
end
