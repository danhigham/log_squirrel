require 'rubygems'
require 'bundler/setup'

require 'sidekiq'
require './init_redis'
require './lib/log_squirrel'

class LogWorker

  include Sidekiq::Worker

  def self.begin(job)
    self.perform_async job
  end

  def perform(job)
    log_squirrel = LogSquirrel.new
    log_squirrel.upload_paths job
  end

end