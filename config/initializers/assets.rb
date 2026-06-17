# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

Rails.application.config.dartsass.builds = {
  "application.scss" => "application.css",
  "trix.scss" => "trix.css"
}

Rails.application.config.dartsass.build_options << "--quiet-deps"
Rails.application.config.dartsass.build_options << "--silence-deprecation=import"
Rails.application.config.dartsass.build_options << "--silence-deprecation=color-functions"
Rails.application.config.dartsass.build_options << "--silence-deprecation=global-builtin"
Rails.application.config.dartsass.build_options << "--silence-deprecation=mixed-decls"
