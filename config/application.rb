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

    config.active_job.queue_adapter = :inline # Ensure inline jobs for testing

    Rails.application.config.session_store :cookie_store,
                                           key: "_squakjive_session",
                                           same_site: :lax,
                                           secure: Rails.env.production?,
                                           domain: (Rails.env.production? ? ".novasector.net" : nil)
    # Notes:
    # - In development, domain: nil keeps the cookie bound to the exact host (e.g., 192.168.1.11).
    # - In production, domain: ".novasector.net" lets subdomains share the session if needed.
    # - secure is true only in production, so dev over HTTP still works.

  end
end
