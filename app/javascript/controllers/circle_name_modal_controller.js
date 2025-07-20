import { Controller } from "@hotwired/stimulus"
import { Modal } from "bootstrap"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.modal = new Modal(this.element)
    this.modal.show()

    this.element.addEventListener('shown.bs.modal', () => {
      this.inputTarget.focus()
    })
  }

  disconnect() {
    this.modal.hide()
  }

  // Close modal on successful form submission
  closeWithSuccess() {
    this.modal.hide()
  }
}
