class ApplicationController < ActionController::Base
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder

  helper_method :current_consumer

  def current_consumer
    @current_consumer ||= Consumer.load(consumer_id)
  end

private

  def consumer_id
    params[:consumer_id] || session[:consumer_id]
  end
end
