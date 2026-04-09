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

    response = client.respond_to_auth_challenge(
      client_id: TradeTariffIdentity.cognito_client_id,
      challenge_name: "CUSTOM_CHALLENGE",
      session: auth,
      challenge_responses: {
        "USERNAME" => email,
        "ANSWER" => token,
      },
    )

    # Set email as verified
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

  def find_or_create_user(email)
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

  def add_user_to_consumer_group(email)
    client.admin_add_user_to_group(
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      username: email,
      group_name: current_consumer.id,
    )
  end

  def initiate_passwordless_auth(email)
    client.admin_initiate_auth(
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      client_id: TradeTariffIdentity.cognito_client_id,
      auth_flow: "CUSTOM_AUTH",
      auth_parameters: { "USERNAME" => email },
    )
  end

  def permitted_params
    params.require(:passwordless_form).permit(:email)
  end

  def client
    @client ||= TradeTariffIdentity.cognito_client
  end
end
