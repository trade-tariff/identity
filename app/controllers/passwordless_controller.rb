class PasswordlessController < ApplicationController
  include TokenEncryption

  def create
    @passwordless = PasswordlessForm.new(permitted_params)

    unless @passwordless.valid?
      render "sessions/new" and return
    end

    email = @passwordless.email

    # try to create the user if they don't exist
    begin
      cognito.find_user(email)
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      cognito.create_user(email, email:)
    end

    cognito.add_to_group(email, group_name: current_consumer.id)

    # Start custom auth to trigger your Lambda to send the link
    resp = cognito.initiate_custom_auth(email)

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

    response = cognito.respond_to_custom_challenge(
      session: auth,
      username: email,
      answer: token,
    )

    # Set email as verified
    cognito.update_user_attributes(email, [{ name: "email_verified", value: "true" }])

    set_cookies(response.authentication_result)

    redirect_to current_consumer.success_url, allow_other_host: true
  rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
    redirect_to current_consumer.failure_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to current_consumer.failure_url, allow_other_host: true
  end

private

  def permitted_params
    params.require(:passwordless_form).permit(:email)
  end

  def cognito
    @cognito ||= CognitoServiceAdapter.new
  end
end
