#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

require 'cfoundry'
require 'zip/zip'

config = YAML.load_file("./config.yml")

puts "* Connecting to Cloud Foundry"

client = CFoundry::Client.new config[:cf_endpoint]
client.login config[:username], config[:password]

service_name = 'log-squirrel-redis'
app_name = 'log-squirrel'
worker_app_name = 'log-squirrel-worker'

puts "* Compressing application"

files_to_ignore = ['app.zip', 'README.md']
folder = Dir.pwd

Zip::ZipFile.open('app.zip', Zip::ZipFile::CREATE) do |zipfile|
  Dir.glob('**/*').each do |filename|
    zipfile.add(filename, File.join(folder, filename)) if not files_to_ignore.include? filename
  end
end

# Create redis service
service = client.service_instance_by_name service_name

if service.nil?
  puts "* Creating redis service"

  service = client.service_instance service_name
  service.vendor = 'redis'
  service.version = '2.6'
  service.tier = 'free'
  service.create!
end

# Create app 
app = client.app_by_name app_name

if app.nil?
  puts "* Creating scheduling app"

  app = client.app app_name
  app.instances = 1
  app.memory = 64
  app.services = [service]
  app.framework_name = 'standalone'
  app.command = 'bundle exec ./app.rb'
  app.runtime_name = 'ruby19'
  app.create!
else
  puts "* Stopping scheduling app"

  app.stop!
end

# Create worker app 
worker_app = client.app_by_name worker_app_name

if worker_app.nil?
  puts "* Creating worker app"

  worker_app = client.app worker_app_name
  worker_app.instances = 1
  worker_app.memory = 64
  worker_app.services = [service]
  worker_app.framework_name = 'standalone'
  worker_app.command = 'bundle exec sidekiq -r ./log_worker.rb'
  worker_app.runtime_name = 'ruby19'
  worker_app.create!
else
  puts "* Stopping worker app"

  worker_app.stop!
end

puts "* Uploading"

app.upload 'app.zip'
worker_app.upload 'app.zip'

File.delete 'app.zip'

puts "* Starting"

app.start!
worker_app.start!