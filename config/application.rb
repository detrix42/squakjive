require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Jitter
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.asset_pipeline = :propshaft

    # Enable MuPDF-based previews for PDFs in all environments
    # config.active_storage.previewers << ActiveStorage::Previewer::MuPDFPreviewer
    # config.active_storage.previewers = [
    #   ActiveStorage::Previewer::PopplerPreviewer,
    #   ActiveStorage::Previewer::VideoPreviewer
    # ]

    # Use libvips for image variants (fast and recommended)
    config.active_storage.variant_processor = :vips

    # Set URL options for Active Storage to generate correct URLs in development
    config.active_storage.url_options = {
      host: '192.168.1.11',
      port: 4200,
      protocol: 'http'
    }

    config.action_controller.default_url_options = {
      host: '192.168.1.11',
      port: 4200,
      protocol: 'http' }
    config.active_job.queue_adapter = :inline # Ensure inline jobs for testing
  end
end
