// app/javascript/controllers/image_lightbox_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    if (
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
    ) return

    event.preventDefault()
    const href = this.element.getAttribute("href")
    if (!href) return

    this.showOverlay(href)
  }

  showOverlay(src) {
    this.overlay = document.createElement("div")
    this.overlay.classList.add("lightbox-overlay")
    this.overlay.setAttribute("role", "dialog")
    this.overlay.setAttribute("aria-modal", "true")

    const container = document.createElement("div")
    container.classList.add("lightbox-container")

    const img = document.createElement("img")
    img.classList.add("lightbox-image")
    img.src = src
    img.alt = ""
    img.draggable = true

    const closeBtn = document.createElement("button")
    closeBtn.type = "button"
    closeBtn.classList.add("lightbox-close")
    closeBtn.setAttribute("aria-label", "Close")
    closeBtn.innerHTML = "×"

    container.appendChild(img)
    container.appendChild(closeBtn)
    this.overlay.appendChild(container)
    document.body.appendChild(this.overlay)

    this._escHandler = (e) => { if (e.key === "Escape") this.close() }
    this._clickOverlay = (e) => { if (e.target === this.overlay) this.close() }
    this._clickClose = () => this.close()

    document.addEventListener("keydown", this._escHandler)
    this.overlay.addEventListener("click", this._clickOverlay)
    closeBtn.addEventListener("click", this._clickClose)
  }

  close() {
    if (this.overlay?.parentNode) {
      document.removeEventListener("keydown", this._escHandler)
      this.overlay.removeEventListener("click", this._clickOverlay)
      this.overlay.parentNode.removeChild(this.overlay)
      this.overlay = null
    }
  }
}
