class SessionsController < ApplicationController
  def index
    session[:consumer_id] = current_consumer.id
    redirect_to login_path
  end

  def new; end
end
