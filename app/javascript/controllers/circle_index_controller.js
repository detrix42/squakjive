import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
  }

  disconnect() {
    this.element.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
  }

  handleCircleSelection = (event) => {
    const circleId = event.detail.circleId
    // Here you can handle the circle selection
    // circleId will be null for "All Circles"
    // or the actual circle ID for specific circles
  }
}
