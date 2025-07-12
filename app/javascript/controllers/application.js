import { Application } from "@hotwired/stimulus"
import HelloController from "./hello_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus   = application

application.register("hello", HelloController)

export { application }
