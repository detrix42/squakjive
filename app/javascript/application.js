import "trix"
// import "@rails/actiontext"

// ;(async () => {
//   if (!window.Trix) {
//     // Fallback: load Trix if not present for any reason
//     await import("trix")
//   }
//   try {
//     setTimeout(() => {
//       import("@rails/actiontext")
//       console.log("Action Text registered:", !!customElements.get("action-text-attachment"))
//         }, 100
//     )
//
//   } catch (e) {
//     console.error("Failed to import @rails/actiontext", e)
//   }
// })()

import "@hotwired/turbo-rails"
import "controllers"
import "channels"

Trix.config.attachments.preview.caption = {
  name: false,
  size: false
}


// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()


