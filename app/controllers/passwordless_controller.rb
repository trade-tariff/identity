class PasswordlessController < ApplicationController
  include TokenEncryption

  def create
    @passwordless = PasswordlessForm.new(permitted_params)

    unless @passwordless.valid?
      render "sessions/new" and return
    end

    email = @passwordless.email

    find_or_create_user(email)
    add_user_to_consumer_group(email)

    resp = initiate_passwordless_auth(email)

    session[:email] = email
    session[:login] = resp.session

    redirect_to passwordless_path
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to login_path, alert: "Something went wrong. Please try again."
  end

  def show
    @email = session[:email]
    if @email.nil?
      redirect_to login_path
    end
  end

  def callback
    email = params[:email]
    token = params[:token]
    auth = session[:login]

    if current_consumer.nil?
      @verification_link = request.original_url
      render :invalid and return
    end

    token_service = TokenService.new
    tokens = token_service.exchange_challenge(session: auth, username: email, answer: token)

    # Set email as verified
    token_service.verify_email(email)

    set_cookies(tokens)

    redirect_to current_consumer.success_url, allow_other_host: true
  rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
    redirect_to current_consumer.failure_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to current_consumer.failure_url, allow_other_host: true
  end

private

  def find_or_create_user(email)
    cognito.find_user(email)
  rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
    cognito.create_user(email, email:)
  end

  def add_user_to_consumer_group(email)
    cognito.add_to_group(email, group_name: current_consumer.id)
  end

  def initiate_passwordless_auth(email)
    cognito.initiate_custom_auth(email)
  end

  def permitted_params
    params.require(:passwordless_form).permit(:email)
  end

  def cognito
    @cognito ||= CognitoServiceAdapter.new
  end
end
