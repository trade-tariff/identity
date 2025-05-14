class ApplicationController < ActionController::Base
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder

  helper_method :current_consumer

  def current_consumer
    @current_consumer ||= begin
      consumer = Consumer.load(consumer_id)

      raise ActionController::BadRequest unless consumer

      consumer
    end
  end

private

  def consumer_id
    session[:consumer_id] || params[:consumer_id]
  end
end
