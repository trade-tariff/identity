class PasswordlessController < ApplicationController
  include TokenEncryption

  RESEND_COOLDOWN = 30.seconds

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
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error(e.full_message)
    redirect_to login_path, alert: "Something went wrong. Please try again."
  end

  def show
    @email = session[:email]
    if @email.nil?
      redirect_to login_path and return
    end

    @passwordless_code = PasswordlessCodeForm.new
  end

  def verify
    @email = session[:email]
    if @email.nil? || session[:login].nil?
      redirect_to login_path and return
    end

    @passwordless_code = PasswordlessCodeForm.new(permitted_code_params)

    unless @passwordless_code.valid?
      render :show and return
    end

    resp = TokenService.new.exchange_challenge(session: session[:login], username: @email, answer: @passwordless_code.code)

    if resp.authentication_result
      complete_sign_in(resp.authentication_result)
    else
      session[:login] = resp.session
      @passwordless_code.errors.add(:code, "The code you entered is incorrect. Enter the code again, or request a new one.")
      render :show
    end
  rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
    @passwordless_code.errors.add(:code, "You've entered the wrong code too many times, or it has expired. Request a new code.")
    render :show
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error(e.full_message)
    redirect_to current_consumer.failure_url, allow_other_host: true
  end

  def resend
    email = session[:email]
    if email.nil?
      redirect_to login_path and return
    end

    if resend_on_cooldown?
      redirect_to passwordless_path, alert: "Please wait a short while before requesting another code." and return
    end

    resp = initiate_passwordless_auth(email)
    session[:login] = resp.session
    session[:last_resend_at] = Time.current.to_i

    redirect_to passwordless_path, notice: "We've sent you a new code."
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to login_path, alert: "Something went wrong. Please try again."
  end

private

  def complete_sign_in(tokens)
    TokenService.new.verify_email(@email)
    set_cookies(tokens)
    redirect_to success_url, allow_other_host: true
  end

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

  def resend_on_cooldown?
    last_resend_at = session[:last_resend_at]
    last_resend_at.present? && Time.current.to_i < last_resend_at + RESEND_COOLDOWN
  end

  def permitted_params
    params.require(:passwordless_form).permit(:email)
  end

  def permitted_code_params
    params.require(:passwordless_code_form).permit(:code)
  end

  def cognito
    @cognito ||= CognitoServiceAdapter.new
  end
end
