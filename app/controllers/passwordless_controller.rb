class PasswordlessController < ApplicationController
  def create
    @passwordless = PasswordlessForm.new(email: params[:email])

    unless @passwordless.valid?
      render "sessions/new" and return
    end

    email = @passwordless.email

    # try to create the user if they don’t exist
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

    # Start custom auth to trigger your Lambda to send the link
    resp = client.admin_initiate_auth(
      user_pool_id: TradeTariffIdentity.cognito_user_pool_id,
      client_id: TradeTariffIdentity.cognito_client_id,
      auth_flow: "CUSTOM_AUTH",
      auth_parameters: { "USERNAME" => email },
    )

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
    consumer_id = params[:consumer]
    token = params[:token]
    auth = session[:login]

    if consumer_id.present?
      session[:consumer_id] = consumer_id
    end

    result = client.respond_to_auth_challenge(
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

    cookies[:id_token] = {
      value: encrypted(result.authentication_result.id_token),
      httponly: true,
      domain: ".#{current_consumer.cookie_domain}",
      expires: 1.day.from_now,
    }

    redirect_to current_consumer.success_url, allow_other_host: true
  rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
    redirect_to current_consumer.failure_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error(e)
    redirect_to current_consumer.failure_url, allow_other_host: true
  end

private

  def client
    @client ||= TradeTariffIdentity.cognito_client
  end

  def encrypted(token)
    if Rails.env.development?
      token
    else
      EncryptionService.encrypt_string(token)
    end
  end
end
