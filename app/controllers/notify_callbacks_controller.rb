class NotifyCallbacksController < ActionController::API
  METRIC_NAMESPACE = "TradeTariff/Notify".freeze
  FAILURE_STATUSES = %w[permanent-failure technical-failure].freeze

  before_action :verify_notify_token

  def create
    put_cloudwatch_metric if FAILURE_STATUSES.include?(params[:status])
    head :ok
  end

private

  def verify_notify_token
    expected = ENV.fetch("NOTIFY_CALLBACK_BEARER_TOKEN", "")
    return head :forbidden if expected.blank?

    provided = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def put_cloudwatch_metric
    Aws::CloudWatch::Client.new.put_metric_data(
      namespace: METRIC_NAMESPACE,
      metric_data: [{
        metric_name: "DeliveryFailures",
        value: 1,
        unit: "Count",
        dimensions: [
          { name: "Environment", value: Rails.env },
          { name: "Pipeline", value: "identity" },
        ],
      }],
    )
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error("notify_cloudwatch_metric_failed: #{e.class.name}: #{e.message}")
  end
end
