require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'fog'
require 'cfoundry'
require 'tempfile'
require 'zip/zip'

class LogSquirrel
    
  def initialize()
    @config = YAML.load_file("./config.yml")
  end

  def jobs(frequency)
    @config[:jobs].select { |j| j[:frequency] == frequency }
  end

  def upload_paths(job)

    upload_time = Time.now.strftime '%Y%m%d-%H%M'

    storage = Fog::Storage.new @config[:fog_storage]

    creds = { :username => @config[:username], :password => @config[:password] }

    c = CFoundry::Client.new @config[:cf_endpoint]
    c.login creds

    app_name = job['application']
    app = c.app_by_name app_name 

    return if app.nil?

    directory = storage.directories.get(@config[:remote_folder])

    return if directory.nil?

    archive = job['archive']

    backup_folder = directory.files.create :key => "#{app_name}-#{upload_time}/" if not archive

    files_to_zip = {}

    job['paths'].each do |file_path|

      begin

        content = app.file(file_path)

        local_path = file_path.match(/\/([^\/]+)$/)[1]

        tempfile = Tempfile.new(local_path)
        tempfile.write(content)
        tempfile.close

        if archive
          files_to_zip[local_path] = tempfile
        else

          directory.files.create(
            :key    => "#{backup_folder.key}#{local_path}",
            :body   => File.open(tempfile.path),
            :public => true
          ) if not archive

          tempfile.unlink
        end

      rescue CFoundry::NotFound
        puts "404!"
      end

    end

    if not files_to_zip.empty?

      temp_zip_file = Tempfile.new("#{app_name}.zip")
      temp_folder = temp_zip_file.path.match(/(.+)\/([^\/]+)$/)[1]

      temp_zip_path = "#{temp_folder}/#{app_name}-#{upload_time}.zip"

      Zip::ZipFile.open(temp_zip_path, Zip::ZipFile::CREATE) do |zipfile|
        files_to_zip.each do |local, temp_file|
          zipfile.add(local, temp_file.path)
        end
      end
      
      directory.files.create(
        :key    => "#{app_name}-#{upload_time}.zip",
        :body   => File.open(temp_zip_path),
        :public => true
      )

      files_to_zip.each { |path, file| file.unlink }
      temp_zip_file.unlink
    end

  end

end