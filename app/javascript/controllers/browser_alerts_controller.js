import { Controller } from "@hotwired/stimulus"

const HIDDEN_POLL_INTERVAL_MS = 2000

export default class extends Controller {
  static targets = ["bridge"]

  static values = {
    unreadCircleIds: { type: Array, default: [] },
    selectedCircleId: { type: Number, default: 0 }
  }

  connect() {
    this.baseTitle = document.title.replace(/^\(\d+\)\s+/, "")
    this.hiddenPollTimer = null
    this.unreadIds = new Set(this.unreadCircleIdsValue.map(id => Number(id)))
    this.dismissUnreadForSelectedCircle()
    this.observer = new MutationObserver(() => this.processBridgeEvents())
    if (this.hasBridgeTarget) {
      this.observer.observe(this.bridgeTarget, { childList: true, subtree: true })
    }

    window.addEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.addEventListener("turbo:before-stream-render", this.handleTurboStream)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    this.syncUnreadUi()
    this.updateTabBadge()
    this.startHiddenPollingIfNeeded()
  }

  disconnect() {
    this.observer?.disconnect()
    this.stopHiddenPolling()
    window.removeEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.removeEventListener("turbo:before-stream-render", this.handleTurboStream)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    document.title = this.baseTitle
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

    if (document.visibilityState === "hidden") {
      this.unreadIds.add(circleId)
    } else {
      this.unreadIds.delete(circleId)
    }
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
    if (id === Number(this.selectedCircleIdValue) && document.visibilityState === "visible") return

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

  tabNotificationCount() {
    const selectedId = Number(this.selectedCircleIdValue)
    const tabIsVisible = document.visibilityState === "visible"
    let count = 0

    this.unreadIds.forEach((id) => {
      if (id === selectedId && tabIsVisible) return
      count++
    })

    return count
  }

  updateTabBadge() {
    const count = this.tabNotificationCount()
    if (count > 0) {
      document.title = `(${count}) ${this.baseTitle}`
      this.setAppBadge(count)
    } else {
      document.title = this.baseTitle
      this.clearAppBadge()
    }
  }

  handleVisibilityChange = async () => {
    if (document.visibilityState === "hidden") {
      this.startHiddenPolling()
      return
    }

    this.stopHiddenPolling()

    // Flush any alert events that were queued while the tab was in the background.
    this.processBridgeEvents()

    const circleId = Number(this.selectedCircleIdValue)
    if (circleId) {
      try {
        const resp = await fetch(`/squaks/${circleId}`, {
          headers: { Accept: "text/vnd.turbo-stream.html" },
          credentials: "same-origin"
        })

        if (resp.ok) {
          const html = await resp.text()
          if (html && html.includes("<turbo-stream")) {
            Turbo.renderStreamMessage(html)
          }
        }
      } catch (_) {
        // Network failure while resyncing; keep current feed and retry on next focus.
      }
    }

    await this.pollUnreadAlerts()
    this.dismissUnreadForSelectedCircle()
    this.syncUnreadUi()
    this.updateTabBadge()
  }

  startHiddenPollingIfNeeded() {
    if (document.visibilityState === "hidden") {
      this.startHiddenPolling()
    }
  }

  startHiddenPolling() {
    if (this.hiddenPollTimer) return

    this.pollUnreadAlerts()
    this.hiddenPollTimer = setInterval(() => this.pollUnreadAlerts(), HIDDEN_POLL_INTERVAL_MS)
  }

  stopHiddenPolling() {
    if (!this.hiddenPollTimer) return

    clearInterval(this.hiddenPollTimer)
    this.hiddenPollTimer = null
  }

  async pollUnreadAlerts() {
    try {
      const resp = await fetch("/user_profile/unread_alerts", {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!resp.ok) return

      const data = await resp.json()
      this.applyUnreadIds(data.unread_circle_ids)
    } catch (_) {
      // Retry on the next poll while the tab stays in the background.
    }
  }

  applyUnreadIds(ids) {
    this.unreadIds = new Set((ids || []).map((id) => Number(id)))

    if (document.visibilityState === "visible") {
      this.dismissUnreadForSelectedCircle()
    }

    this.syncUnreadUi()
    this.updateTabBadge()
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