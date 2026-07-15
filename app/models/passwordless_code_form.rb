class PasswordlessCodeForm
  include ActiveModel::Model
  attr_accessor :code

  CODE_REGEX = /\A\d{6}\z/

  validates :code, presence: { message: "Enter the 6-digit code from your email" },
                   format: { with: CODE_REGEX, message: "Enter the 6-digit code from your email" }
end
