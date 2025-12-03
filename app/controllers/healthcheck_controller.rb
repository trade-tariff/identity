class HealthcheckController < ApplicationController
  skip_before_action :verify_authenticity_token

  def check
    NewRelic::Agent.ignore_transaction
    render json: { status: "ok" }, status: :ok
  end

  def checkz
    NewRelic::Agent.ignore_transaction
    render json: { status: "ok" }, status: :ok
  end
end
