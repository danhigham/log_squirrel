#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'clockwork'

require './log_worker'
require './lib/log_squirrel'

include Clockwork

log_squirrel = LogSquirrel.new

handler do |frequency|

  puts "Running #{frequency}"
  jobs = log_squirrel.jobs(frequency)

  jobs.each do |job|
    LogWorker.begin job
  end

end

every(1.hour, :hour)
every(1.day, :day)
every(1.week, :week)

Clockwork::run