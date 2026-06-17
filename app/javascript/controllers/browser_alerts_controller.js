import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bridge"]

  static values = {
    unreadCircleIds: { type: Array, default: [] },
    selectedCircleId: { type: Number, default: 0 },
    faviconUrl: { type: String, default: "" }
  }

  connect() {
    this.unreadIds = new Set(this.unreadCircleIdsValue.map(id => Number(id)))
    this.baseFaviconHref = this.resolveBaseFaviconHref()
    this.observer = new MutationObserver(() => this.processBridgeEvents())
    if (this.hasBridgeTarget) {
      this.observer.observe(this.bridgeTarget, { childList: true, subtree: true })
    }

    window.addEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.addEventListener("turbo:before-stream-render", this.handleTurboStream)

    this.syncUnreadUi()
    this.updateTabBadge()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.removeEventListener("turbo:before-stream-render", this.handleTurboStream)
    this.restoreFavicon()
    this.clearAppBadge()
  }

  handleCircleSelected = (event) => {
    const circleId = Number(event.detail?.circleId)
    if (!circleId) return

    this.selectedCircleIdValue = circleId
    this.markCircleRead(circleId)
  }

  handleTurboStream = (event) => {
    const newStream = event.detail?.newStream
    if (!newStream) return

    const action = newStream.getAttribute("action")
    const target = newStream.getAttribute("target")
    if (action !== "prepend" || target !== "squaks-list") return

    const circleId = this.selectedCircleIdValue
    if (!circleId) return

    this.markCircleRead(circleId)
  }

  processBridgeEvents() {
    if (!this.hasBridgeTarget) return

    this.bridgeTarget.querySelectorAll("[data-browser-alerts-event]").forEach((node) => {
      const circleId = Number(node.dataset.circleId)
      const action = node.dataset.alertAction
      if (!circleId || !action) return

      if (action === "mark_unread") {
        this.markCircleUnread(circleId)
      } else if (action === "mark_read") {
        this.markCircleRead(circleId)
      }

      node.remove()
    })
  }

  markCircleUnread(circleId) {
    if (circleId === this.selectedCircleIdValue) return

    this.unreadIds.add(circleId)
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  markCircleRead(circleId) {
    if (!this.unreadIds.delete(circleId)) {
      this.syncCircleItem(circleId, false)
      this.updateTabBadge()
      return
    }

    this.syncUnreadUi()
    this.updateTabBadge()
  }

  syncUnreadUi() {
    this.element.querySelectorAll(".circle-item").forEach((item) => {
      const circleId = Number(item.dataset.circlesCircleId)
      const unread = this.unreadIds.has(circleId)
      item.classList.toggle("unread", unread && !item.classList.contains("selected"))
    })
  }

  syncCircleItem(circleId, unread) {
    const item = document.getElementById(`circle-id-${circleId}`)
    if (!item) return
    item.classList.toggle("unread", unread && !item.classList.contains("selected"))
  }

  unreadCount() {
    return this.unreadIds.size
  }

  updateTabBadge() {
    const count = this.unreadCount()
    if (count > 0) {
      this.setFaviconBadge()
      this.setAppBadge(count)
    } else {
      this.restoreFavicon()
      this.clearAppBadge()
    }
  }

  resolveBaseFaviconHref() {
    if (this.faviconUrlValue) return this.faviconUrlValue

    const brandIcon = document.querySelector('link[data-squakjive-brand-icon="true"]')
    if (brandIcon?.href) return brandIcon.href

    const iconLink = document.querySelector('link[rel="icon"]')
    return iconLink?.href || "/icon.png"
  }

  setFaviconBadge() {
    const image = new Image()
    image.crossOrigin = "anonymous"
    image.onload = () => {
      const size = 32
      const canvas = document.createElement("canvas")
      canvas.width = size
      canvas.height = size
      const ctx = canvas.getContext("2d")
      ctx.drawImage(image, 0, 0, size, size)

      ctx.fillStyle = "#e53935"
      ctx.beginPath()
      ctx.arc(size - 7, 7, 6, 0, Math.PI * 2)
      ctx.fill()
      ctx.strokeStyle = "#ffffff"
      ctx.lineWidth = 1.5
      ctx.stroke()

      this.applyFavicon(canvas.toDataURL("image/png"))
    }
    image.onerror = () => {
      this.applyFavicon(this.badgeFallbackDataUrl())
    }
    image.src = this.baseFaviconHref
  }

  badgeFallbackDataUrl() {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
      <rect width="32" height="32" rx="6" fill="#0a1628"/>
      <circle cx="25" cy="7" r="6" fill="#e53935" stroke="#fff" stroke-width="1.5"/>
    </svg>`
    return `data:image/svg+xml,${encodeURIComponent(svg)}`
  }

  applyFavicon(href) {
    const brandIcon = document.querySelector('link[data-squakjive-brand-icon="true"]')
    if (brandIcon) brandIcon.setAttribute("disabled", "true")

    let link = document.querySelector('link[data-browser-alerts-favicon="true"]')
    if (!link) {
      link = document.createElement("link")
      link.rel = "icon"
      link.type = "image/png"
      link.dataset.browserAlertsFavicon = "true"
      document.head.appendChild(link)
    }
    link.href = href
  }

  restoreFavicon() {
    const badgeLink = document.querySelector('link[data-browser-alerts-favicon="true"]')
    badgeLink?.remove()

    const brandIcon = document.querySelector('link[data-squakjive-brand-icon="true"]')
    if (brandIcon) brandIcon.removeAttribute("disabled")
  }

  async setAppBadge(count) {
    if (!("setAppBadge" in navigator)) return
    try {
      await navigator.setAppBadge(count)
    } catch (_) {
      // Unsupported or blocked by the browser.
    }
  }

  async clearAppBadge() {
    if (!("clearAppBadge" in navigator)) return
    try {
      await navigator.clearAppBadge()
    } catch (_) {
      // Unsupported or blocked by the browser.
    }
  }
}