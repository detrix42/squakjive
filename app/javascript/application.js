import "@hotwired/turbo-rails"
import "controllers"
import "channels"

// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

import "trix"
import "@rails/actiontext"
