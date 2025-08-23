import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // optional: debounce for large lists
    this._debounced = this.debounce((q) => this.emit(q), 120)
  }

  onInput(event) {
    const query = (event.target.value || "").trim().toLowerCase()
    if (this._debounced) return this._debounced(query)
    this.emit(query)
  }

  emit(query) {
    this.element.dispatchEvent(
        new CustomEvent("user-search:filter", {
          detail: { query },
          bubbles: true,
        })
    )
  }

  debounce(fn, delay) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn.apply(this, args), delay)
    }
  }
}
