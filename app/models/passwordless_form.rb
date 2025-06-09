class PasswordlessForm
  include ActiveModel::Model
  attr_accessor :email

  validates :email, presence: { message: "Enter an email address in the correct format, like name@example.com" },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "Enter an email address in the correct format, like name@example.com" }
end
