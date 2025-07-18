import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    // Select "All Circles" by default
    this.select({ target: this.itemTargets[0] })
  }

  select(event) {
    // Remove 'selected' class from all items
    this.itemTargets.forEach(item => {
      item.classList.remove('selected')
    })

    // Add 'selected' class to clicked item
    const selectedItem = event.target.closest('[data-circle-selection-target="item"]')
    selectedItem.classList.add('selected')

    // Get circle_id from data attribute
    const circleId = selectedItem.dataset.circleId

    // Dispatch custom event with circle_id (null for "All Circles")
    const detail = { circleId: circleId === '' ? null : parseInt(circleId) }
    this.dispatch('circleSelected', { detail })
  }
}
