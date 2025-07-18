import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    if (this.hasContentTarget) {
      const markdown = this.contentTarget.textContent.trim()
      this.contentTarget.innerHTML = marked.parse(markdown)
    }
  }
}
