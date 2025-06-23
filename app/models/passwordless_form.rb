class PasswordlessForm
  include ActiveModel::Model
  attr_accessor :email

  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  validates :email, presence: { message: "Enter an email address in the correct format, like name@example.com" },
                    format: { with: EMAIL_REGEX, message: "Enter an email address in the correct format, like name@example.com" }
end
