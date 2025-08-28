class Notification::Bundle::DeliverAllJob < ApplicationJob
  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Notification::Bundle.deliver_all
    end
  end
end
