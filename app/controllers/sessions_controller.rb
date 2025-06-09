class SessionsController < ApplicationController
  def index
    session[:consumer_id] = current_consumer.id
    redirect_to login_path
  end

  def new
    if current_consumer.passwordless?
      @passwordless = PasswordlessForm.new
    end
  end
end
