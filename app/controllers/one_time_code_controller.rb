class OneTimeCodeController < ApplicationController
  include TokenEncryption

  def create
    @one_time_code = PasswordlessForm.new(permitted_email_params)

    unless @one_time_code.valid?
      @passwordless = PasswordlessForm.new
      render "sessions/new" and return
    end

    email = @one_time_code.email

    begin
      client.admin_get_user(
        user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
        username: email,
      )
    rescue Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      client.admin_create_user(
        user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
        username: email,
        user_attributes: [{ name: "email", value: email }],
        message_action: "SUPPRESS",
      )
    end

    client.admin_add_user_to_group(
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      username: email,
      group_name: current_consumer.id,
    )

    resp = client.admin_initiate_auth(
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      client_id: TradeTariffIdentity.otp_cognito_client_id,
      auth_flow: "CUSTOM_AUTH",
      auth_parameters: { "USERNAME" => email },
    )

    session[:otp_email] = email
    session[:otp_login] = resp.session

    redirect_to one_time_code_path
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to login_path, alert: "Something went wrong. Please try again."
  end

  def show
    @email = session[:otp_email]
    if @email.nil?
      redirect_to login_path
    end
  end

  def verify
    if current_consumer.nil?
      render :invalid and return
    end

    email = session[:otp_email]
    auth = session[:otp_login]

    if email.nil?
      redirect_to login_path and return
    end

    @one_time_code_form = OneTimeCodeForm.new(permitted_code_params)

    unless @one_time_code_form.valid?
      @email = email
      render :show and return
    end

    response = client.respond_to_auth_challenge(
      client_id: TradeTariffIdentity.otp_cognito_client_id,
      challenge_name: "CUSTOM_CHALLENGE",
      session: auth,
      challenge_responses: {
        "USERNAME" => email,
        "ANSWER" => @one_time_code_form.code,
      },
    )

    client.admin_update_user_attributes({
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      username: email,
      user_attributes: [{ name: "email_verified", value: "true" }],
    })

    set_cookies(response.authentication_result)

    redirect_to current_consumer.success_url, allow_other_host: true
  rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
    redirect_to current_consumer.failure_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to current_consumer.failure_url, allow_other_host: true
  end

private

  def permitted_email_params
    params.require(:passwordless_form).permit(:email)
  end

  def permitted_code_params
    params.require(:one_time_code_form).permit(:code)
  end

  def client
    @client ||= TradeTariffIdentity.cognito_client
  end
end
