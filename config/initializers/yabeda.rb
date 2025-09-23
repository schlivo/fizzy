require "prometheus/client/support/puma"

Prometheus::Client.configuration.logger = Rails.logger
Prometheus::Client.configuration.pid_provider = Prometheus::Client::Support::Puma.method(:worker_pid_provider)
Yabeda::Rails.config.controller_name_case = :camel

Yabeda::ActiveJob.install!

require "yabeda/solid_queue"
Yabeda::SolidQueue.install!
