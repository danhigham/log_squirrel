require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'fog'
require 'cfoundry'
require 'tempfile'

class LogSquirrel
    
  def initialize()
    @config = YAML.load_file("./config.yml")
  end

  def jobs(frequency)
    @config[:jobs].select { |j| j[:frequency] == frequency }
  end

  def upload_paths(job)

    upload_time = Time.now.to_s

    storage = Fog::Storage.new @config[:fog_storage]

    creds = { :username => @config[:username], :password => @config[:password] }

    c = CFoundry::Client.new @config[:cf_endpoint]
    c.login creds

    app_name = job['application']
    app = c.app_by_name app_name

    return if app.nil?

    directory = storage.directories.get(@config[:remote_folder])

    return if directory.nil?

    backup_folder = directory.files.create :key => "#{app_name}-#{upload_time}/"

    job['paths'].each do |file_path|

      begin

        content = app.file(file_path)

        local_path = file_path.match(/\/([^\/]+)$/)[1]

        tempfile = Tempfile.new(local_path)
        tempfile.write(content)
        tempfile.close

        # upload that resume
        directory.files.create(
          :key    => "#{backup_folder.key}#{local_path}",
          :body   => File.open(tempfile.path),
          :public => true
        )

        tempfile.unlink

      rescue CFoundry::NotFound
        puts "404!"
      end
    end

  end

end