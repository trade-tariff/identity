class Consumer
  include ActiveModel::Model

  def self.load(consumer_id)
    return nil unless consumer_id

    consumer_attributes = TradeTariffIdentity::CONSUMERS.find do |consumer|
      consumer[:id] == consumer_id
    end

    return nil unless consumer_attributes

    new(id: consumer_id,
        methods: consumer_attributes[:methods],
        success_url: consumer_attributes[:success_url],
        failure_url: consumer_attributes[:failure_url],
        cookie_domain: consumer_attributes[:cookie_domain])
  end

  attr_accessor :id, :methods, :success_url, :failure_url, :cookie_domain

  def passwordless?
    methods.include?(:passwordless)
  end
end
