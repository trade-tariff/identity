require "rails_helper"
require "capybara/rspec"

RSpec.describe "Passwordless sign-in without JavaScript", type: :feature do
  let(:consumer) { build(:consumer, id: "admin", success_url: "http://www.example.com/healthcheck") }
  let(:cognito) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:tokens) { Data.define(:id_token, :refresh_token).new("id-token", "refresh-token") }
  let(:auth_response) { Data.define(:authentication_result, :session).new(tokens, nil) }

  before do
    allow(Consumer).to receive(:load).with("admin").and_return(consumer)
    allow(TradeTariffIdentity).to receive(:cognito_client).and_return(cognito)
    allow(cognito).to receive_messages(
      admin_get_user: nil,
      admin_add_user_to_group: nil,
      admin_initiate_auth: Data.define(:session).new("challenge-session"),
      respond_to_auth_challenge: auth_response,
      admin_update_user_attributes: nil,
    )

    visit "/?consumer_id=admin"
    fill_in "Email", with: "test@example.com"
    click_button "Continue"
  end

  it "provides a labelled text input with numeric keyboard and autofill hints", :aggregate_failures do
    expect(page).to have_field("6-digit code", type: "text")
    expect(page).to have_css('input[name="passwordless_code_form[code]"][inputmode="numeric"][autocomplete="one-time-code"]')
  end

  it "submits the real input, including a leading zero", :aggregate_failures do
    submit_code("012345")

    expect(cognito).to have_received(:respond_to_auth_challenge).with(
      hash_including(challenge_responses: { "USERNAME" => "test@example.com", "ANSWER" => "012345" }),
    )
    expect(page).to have_current_path("/healthcheck")
  end

  context "with an incomplete code" do
    before { submit_code("12") }

    it "shows an associated error and preserves the input without calling Cognito", :aggregate_failures do
      expect(page).to have_css(".govuk-error-summary", text: "Enter the 6-digit code from your email")
      expect(page).to have_field("6-digit code", with: "12")
      expect(cognito).not_to have_received(:respond_to_auth_challenge)
    end

    it "allows correction" do
      submit_code("012345")

      expect(page).to have_current_path("/healthcheck")
    end
  end

  def submit_code(code)
    fill_in "6-digit code", with: code
    click_button "Continue"
  end
end
