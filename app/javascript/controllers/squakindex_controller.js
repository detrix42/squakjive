import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["squakindex"]

  static values = {
    circleId: Number
  }

  connect() {
    console.log("Squak index controller connected. Squaks for circle:", this.circleIdValue)


  }

  disconnect() {
    // Clear the interval when the controller disconnects

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
