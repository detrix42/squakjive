// app/javascript/controllers/local_time_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { format: String }

  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return

    const date = new Date(iso)
    if (isNaN(date.getTime())) return

    // Default format if none provided
    const fmt = this.formatValue || "MM-dd-yyyy h:mm a"

    this.element.textContent = this.formatDate(date, fmt)
    this.element.title = date.toLocaleString() // tooltip with full local timestamp
  }

  formatDate(date, fmt) {
    // Very small formatter for common tokens
    // Tokens: yyyy, MM, dd, h, hh, mm, a
    const pad = (n) => String(n).padStart(2, "0")
    const hours24 = date.getHours()
    const hours12 = hours24 % 12 || 12
    const ampm = hours24 < 12 ? "AM" : "PM"

    const map = {
      yyyy: String(date.getFullYear()),
      MM: pad(date.getMonth() + 1),
      dd: pad(date.getDate()),
      h: String(hours12),
      hh: pad(hours12),
      mm: pad(date.getMinutes()),
      a: ampm
    }

    return fmt.replace(/yyyy|MM|dd|hh|h|mm|a/g, (t) => map[t] || t)
  }
}
