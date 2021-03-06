#require File.expand_path('../boot', __FILE__)
require_relative 'boot'

require 'csv'
require 'zip'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
#Bundler.require(:default, Rails.env)
Bundler.require(*Rails.groups)

# this enables us to know who created a user or updated a user.
require './lib/with_user'
# Extra methods for alertings
require './lib/alertings_methods'

# class ActiveRecordOverrideRailtie < Rails::Railtie
#   initializer "active_record.initialize_database.override" do |app|

#     ActiveSupport.on_load(:active_record) do
#       if url = ENV['DATABASE_URL']
#         ActiveRecord::Base.connection_pool.disconnect!
#         parsed_url = URI.parse(url)
#         config =  {
#           adapter:             'postgis',
#           host:                parsed_url.host,
#           encoding:            'unicode',
#           database:            parsed_url.path.split("/")[-1],
#           port:                parsed_url.port,
#           username:            parsed_url.user,
#           password:            parsed_url.password
#         }
#         establish_connection(config)
#       end
#     end
#   end
# end

module Trailsyserver
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    config.before_configuration do
      env_file = File.join(Rails.root, 'config', 'local_env.yml')
      YAML.load(File.open(env_file)).each do |key, value|
        ENV[key.to_s] = value
      end if File.exist?(env_file)
    end

    RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config| 
      config.default = RGeo::Geos.factory_generator
      config.default = RGeo::Geographic.spherical_factory(srid: 4326) 
    end
    RGeo::ActiveRecord::GeometryMixin.set_json_generator(:geojson)

    config.middleware.use Rack::Attack
    config.active_job.queue_adapter = :async

    # config.middleware.use Rack::Cors do
    #   allow do
    #     origins '*'
    #     resource '*', :headers => :any, :methods => [:get, :post, :options]
    #   end
    # end
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :options]
      end
    end
    # config.action_dispatch.default_headers = {
    #   'Access-Control-Allow-Origin' => '*',
    #   'Access-Control-Request-Method' => %w{GET OPTIONS}.join(",")
    # }
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Central Time (US & Canada)'
    config.encoding = "utf-8"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.assets.paths << "#{Rails.root}/app/assets/fonts"
    config.assets.precompile += %w( .svg .eot .woff .ttf .gif )
  end
end
