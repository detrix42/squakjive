import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bridge"]

  static values = {
    unreadCircleIds: { type: Array, default: [] },
    selectedCircleId: { type: Number, default: 0 },
    faviconUrl: { type: String, default: "/icon.png" },
    faviconBadgeUrl: { type: String, default: "/icon-badge.png" }
  }

  connect() {
    this.unreadIds = new Set(this.unreadCircleIdsValue.map(id => Number(id)))
    this.dismissUnreadForSelectedCircle()
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
    this.showPlainFavicon()
    this.clearAppBadge()
  }

  circleOpened(event) {
    const item = event.currentTarget.closest(".circle-item")
    if (!item) return

    const circleId = Number(item.dataset.circlesCircleId)
    if (!circleId) return

    this.selectedCircleIdValue = circleId
    this.unreadIds.delete(circleId)
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  handleCircleSelected = (event) => {
    const circleId = Number(event.detail?.circleId)
    if (!circleId) return

    this.selectedCircleIdValue = circleId
    this.unreadIds.delete(circleId)
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  handleTurboStream = (event) => {
    const newStream = event.detail?.newStream
    if (!newStream) return

    const action = newStream.getAttribute("action")
    const target = newStream.getAttribute("target")
    if (action !== "prepend" || target !== "squaks-list") return

    const circleId = Number(this.selectedCircleIdValue)
    if (!circleId) return

    this.unreadIds.delete(circleId)
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  selectedCircleIdValueChanged() {
    this.dismissUnreadForSelectedCircle()
    this.syncUnreadUi()
    this.updateTabBadge()
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
        this.unreadIds.delete(circleId)
        this.syncUnreadUi()
        this.updateTabBadge()
      }

      node.remove()
    })
  }

  markCircleUnread(circleId) {
    const id = Number(circleId)
    if (id === Number(this.selectedCircleIdValue)) return

    this.unreadIds.add(id)
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  dismissUnreadForSelectedCircle() {
    const selectedId = Number(this.selectedCircleIdValue)
    if (!selectedId) return

    this.unreadIds.delete(selectedId)
  }

  syncUnreadUi() {
    this.element.querySelectorAll(".circle-item").forEach((item) => {
      const circleId = Number(item.dataset.circlesCircleId)
      const showUnread = this.unreadIds.has(circleId) && !item.classList.contains("selected")
      item.classList.toggle("unread", showUnread)
    })
  }

  unreadCount() {
    return this.element.querySelectorAll(".circle-item.unread").length
  }

  updateTabBadge() {
    if (this.unreadCount() > 0) {
      this.showBadgedFavicon()
      this.setAppBadge(this.unreadCount())
    } else {
      this.showPlainFavicon()
      this.clearAppBadge()
    }
  }

  brandIconLink() {
    return document.querySelector('link[data-squakjive-brand-icon="true"]')
  }

  showBadgedFavicon() {
    const link = this.brandIconLink()
    if (!link) return

    link.href = this.faviconBadgeUrlValue
  }

  showPlainFavicon() {
    document.querySelector('link[data-browser-alerts-favicon="true"]')?.remove()

    const link = this.brandIconLink()
    if (!link) return

    link.removeAttribute("disabled")
    link.href = this.faviconUrlValue
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
    if (!("setAppBadge" in navigator) && !("clearAppBadge" in navigator)) return
    try {
      if ("clearAppBadge" in navigator) {
        await navigator.clearAppBadge()
      } else {
        await navigator.setAppBadge(0)
      }
    } catch (_) {
      // Unsupported or blocked by the browser.
    }
  }
}