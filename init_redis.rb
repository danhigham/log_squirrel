require 'json'

services = JSON.parse(ENV['VCAP_SERVICES'])
redis_key = services.keys.select { |svc| svc =~ /redis/i }.first
redis = services[redis_key].first['credentials']

Sidekiq.configure_server do |config|
  config.redis = { :url => "redis://#{redis['password']}@#{redis['hostname']}:#{redis['port']}/#{redis['name']}" } # , :namespace => 'mynamespace' 
end