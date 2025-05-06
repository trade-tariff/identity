class Consumer
  include ActiveModel::Model
  include ActiveModel::Attributes

  def self.load(consumer_id)
    return nil unless consumer_id

    consumer_attributes = TradeTariffIdentity::CONSUMERS.find do |consumer|
      consumer[:id] == consumer_id
    end

    return nil unless consumer_attributes

    new(id: consumer_id,
        methods: consumer_attributes[:methods],
        return_url: consumer_attributes[:return_url],
        cookie_domain: consumer_attributes[:cookie_domain])
  end

  attr_accessor :id, :methods, :return_url, :cookie_domain

  def passwordless?
    methods.include?(:passwordless)
  end
end
