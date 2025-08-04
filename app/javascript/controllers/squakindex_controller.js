import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["squakindex"]

  static values = {
    circleId: Number
  }

  connect() {
    console.log("Squak index controller connected.\n Polling for circle: ", this.circleIdValue)

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

  async pollForNewSquaks() {

    const url='/squaks/' + this.circleIdValue
    try {
      const squak_res = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/vnd.turbo-stream.html',
        }
      })
      if (squak_res.ok) {
        const squak_res_text = await squak_res.text()
        Turbo.renderStreamMessage(squak_res_text)
      }
    } catch (error) {
      console.log('network error-> select circle error:', error)
    }
  }


}
