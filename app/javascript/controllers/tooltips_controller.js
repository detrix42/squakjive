// app/javascript/controllers/tooltip_controller.js
import { Controller } from "@hotwired/stimulus"
import { Tooltip } from "bootstrap"

// Connects to data-controller="tooltip"
export default class extends Controller {
  static values = {
    content: String,
    placement: { type: String, default: "auto" },
    html: { type: Boolean, default: false },
  }

  connect() {
    console.log('tooltips connected')
    console.log('tooltip content:', this.contentValue)
    this.tooltip = new Tooltip(this.element, {
      title: this.contentValue || "",
      placement: this.placementValue,
      trigger: "manual",
      container: "body",
      html: this.htmlValue,
      fallbackPlacements: ["right", "left", "top", "bottom"],
      offset: [0, 8],
      customClass: "tooltip-colors"
    })
  }

  disconnect() {
    this.tooltip?.dispose()
    this.tooltip = null

  }

  show() {
    if (this.tooltip) this.tooltip.show()
  }

  hide() {
    if (this.tooltip) this.tooltip.hide()
  }

  // Optional: toggle via click instead of hover
  toggle() {
    if (!this.tooltip) return
    // Bootstrap 5 handles toggle via .tip and ._isShown checks
    const isShown = this.element.getAttribute("aria-describedby")
    isShown ? this.hide() : this.show()
  }
}
