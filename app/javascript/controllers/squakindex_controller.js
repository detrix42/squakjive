import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import TurndownService from "turndown"

export default class extends Controller {
  static targets = ["squakindex"]

  static values = {

  }

  connect() {
    console.log("Squak index controller connected")

    // Set up polling interval
    this.pollingInterval = setInterval(() => {
      this.pollForNewSquaks()
    }, 5000) // Poll every 5 seconds; adjust as needed

  }

  disconnect() {
    // Clear the interval when the controller disconnects
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
    }

  }

  pollForNewSquaks() {
    // TODO: Fetch and process new squaks here
    console.log("Polling for new squaks...")

    
  }


}
