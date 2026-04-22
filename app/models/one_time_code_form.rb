class OneTimeCodeForm
  include ActiveModel::Model
  attr_accessor :code

  validates :code, presence: { message: "Enter the code we sent to your email address" }
end
