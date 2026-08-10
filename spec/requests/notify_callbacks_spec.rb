require "rails_helper"

RSpec.describe "POST /notify/callback", type: :request do
  let(:bearer_token) { "test-notify-bearer-token" }
  let(:valid_headers) { { "Authorization" => "Bearer #{bearer_token}" } }
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }

  before do
    stub_const("ENV", ENV.to_h.merge("NOTIFY_CALLBACK_BEARER_TOKEN" => bearer_token))
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)
    allow(cloudwatch_client).to receive(:put_metric_data)
  end

  def post_callback(status:, headers: valid_headers)
    post notify_callback_path, params: { status: }, as: :json, headers:
  end

  context "when the bearer token is missing" do
    it "returns 403" do
      post_callback(status: "permanent-failure", headers: {})
      expect(response).to have_http_status(:forbidden)
    end

    it "does not emit a metric" do
      post_callback(status: "permanent-failure", headers: {})
      expect(cloudwatch_client).not_to have_received(:put_metric_data)
    end
  end

  context "when the bearer token is wrong" do
    it "returns 403" do
      post_callback(status: "permanent-failure", headers: { "Authorization" => "Bearer wrong-token" })
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when the NOTIFY_CALLBACK_BEARER_TOKEN env var is not set" do
    before do
      stub_const("ENV", ENV.to_h.reject { |k, _| k == "NOTIFY_CALLBACK_BEARER_TOKEN" })
    end

    it "returns 403 regardless of the provided token" do
      post_callback(status: "permanent-failure")
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with a valid bearer token" do
    let(:expected_metric) do
      {
        namespace: "TradeTariff/Notify",
        metric_data: [{
          metric_name: "DeliveryFailures",
          value: 1,
          unit: "Count",
          dimensions: [
            { name: "Environment", value: Rails.env },
            { name: "Pipeline", value: "identity" },
          ],
        }],
      }
    end

    %w[permanent-failure technical-failure].each do |status|
      it "returns 200 for #{status}" do
        post_callback(status:)
        expect(response).to have_http_status(:ok)
      end

      it "emits a CloudWatch DeliveryFailures metric for #{status}" do
        post_callback(status:)
        expect(cloudwatch_client).to have_received(:put_metric_data).with(expected_metric)
      end
    end

    context "when status is temporary-failure" do
      it "returns 200" do
        post_callback(status: "temporary-failure")
        expect(response).to have_http_status(:ok)
      end

      it "does not emit a metric" do
        post_callback(status: "temporary-failure")
        expect(cloudwatch_client).not_to have_received(:put_metric_data)
      end
    end

    context "when status is delivered" do
      it "returns 200" do
        post_callback(status: "delivered")
        expect(response).to have_http_status(:ok)
      end

      it "does not emit a metric" do
        post_callback(status: "delivered")
        expect(cloudwatch_client).not_to have_received(:put_metric_data)
      end
    end

    context "when CloudWatch raises a service error" do
      before do
        allow(cloudwatch_client).to receive(:put_metric_data).and_raise(
          Aws::CloudWatch::Errors::ServiceError.new(nil, "throttled"),
        )
        allow(Rails.logger).to receive(:error)
      end

      it "returns 200" do
        post_callback(status: "permanent-failure")
        expect(response).to have_http_status(:ok)
      end

      it "logs the error" do
        post_callback(status: "permanent-failure")
        expect(Rails.logger).to have_received(:error).with(a_string_including("notify_cloudwatch_metric_failed"))
      end
    end
  end
end
