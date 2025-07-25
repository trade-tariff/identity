class SessionsController < ApplicationController
  before_action :check_consumer

  def index
    session[:consumer_id] = current_consumer.id
    redirect_to login_path
  end

  def new
    if current_consumer.passwordless?
      @passwordless = PasswordlessForm.new
    end
  end

private

  def check_consumer
    redirect_to "/400" and return if current_consumer.nil?
  end
end
