import { Controller } from "@hotwired/stimulus"
import { getAlertBlip } from "utility/alert_blip"
import { TabAlerts } from "utility/tab_alerts"

const HIDDEN_POLL_INTERVAL_MS = 2000

// One shared timer for the whole page so Turbo/Stimulus reconnects cannot leave
// orphaned intervals behind.
const hiddenPoll = {
  timerId: null,
  controller: null,
  abortController: null,

  stop() {
    if (this.timerId) {
      clearTimeout(this.timerId)
      this.timerId = null
    }
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
    this.controller = null
  },

  start(controller) {
    this.stop()
    if (!tabIsHidden()) return

    this.controller = controller
    controller.fetchUnreadAlerts()
    this.schedule()
  },

  schedule() {
    this.timerId = setTimeout(async () => {
      this.timerId = null

      if (!tabIsHidden() || !this.controller) {
        this.stop()
        return
      }

      await this.controller.fetchUnreadAlerts()
      if (tabIsHidden() && this.controller) {
        this.schedule()
      } else {
        this.stop()
      }
    }, HIDDEN_POLL_INTERVAL_MS)
  },

  nextAbortSignal() {
    if (this.abortController) {
      this.abortController.abort()
    }
    this.abortController = new AbortController()
    return this.abortController.signal
  }
}

function tabIsHidden() {
  return document.visibilityState === "hidden"
}

function stopHiddenPolling() {
  hiddenPoll.stop()
}

if (!window.__squakJivePollLifecycleBound) {
  window.__squakJivePollLifecycleBound = true
  window.__squakJiveStopPolling = stopHiddenPolling

  window.addEventListener("pagehide", stopHiddenPolling, { capture: true })
  document.addEventListener("turbo:before-visit", stopHiddenPolling)
  document.addEventListener("visibilitychange", () => {
    if (!tabIsHidden()) {
      stopHiddenPolling()
    }
  })
}

export default class extends Controller {
  static targets = ["bridge"]

  static values = {
    unreadCircleIds: { type: Array, default: [] },
    selectedCircleId: { type: Number, default: 0 }
  }

  initialize() {
    // Stimulus runs *ValueChanged callbacks during connect(), before connect() body runs.
    this.unreadIds = new Set()
    this.resyncingFeed = false
    this.tabReturnInFlight = false
    this.tabWasInactive = false
    // Circle the user already saw live while this tab was focused (server may still flag unread).
    this.seenWhileFocusedCircleId = null
  }

  connect() {
    this.alertBlip = getAlertBlip()
    this.tabAlerts = new TabAlerts({ baseTitle: document.title.replace(/^\(\d+\)\s+/, "") })
    this.unreadIds = new Set(this.unreadCircleIdsValue.map(id => Number(id)))
    this.dismissUnreadForSelectedCircle()
    this.observer = new MutationObserver(() => this.processBridgeEvents())
    if (this.hasBridgeTarget) {
      this.observer.observe(this.bridgeTarget, { childList: true, subtree: true })
    }

    window.addEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.addEventListener("turbo:before-stream-render", this.handleTurboStream)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("blur", this.handleWindowBlur)
    window.addEventListener("focus", this.handleWindowFocus)
    window.addEventListener("pageshow", this.handlePageShow)

    this.syncUnreadUi()
    this.updateTabBadge()

    if (tabIsHidden()) {
      this.tabWasInactive = true
      hiddenPoll.start(this)
    } else {
      hiddenPoll.stop()
    }
  }

  disconnect() {
    this.observer?.disconnect()
    if (hiddenPoll.controller === this) {
      hiddenPoll.stop()
    }
    window.removeEventListener("circle-selection:circleSelected", this.handleCircleSelected)
    document.removeEventListener("turbo:before-stream-render", this.handleTurboStream)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    window.removeEventListener("blur", this.handleWindowBlur)
    window.removeEventListener("focus", this.handleWindowFocus)
    window.removeEventListener("pageshow", this.handlePageShow)
    this.tabAlerts?.reset()
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

    if (tabIsHidden() || !document.hasFocus()) {
      this.addUnread(circleId, { announce: true })
    } else {
      this.markSeenWhileFocused(circleId)
      this.unreadIds.delete(circleId)
      this.syncUnreadUi()
      this.updateTabBadge()
    }
  }

  selectedCircleIdValueChanged() {
    this.seenWhileFocusedCircleId = null
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
    if (this.isActivelyViewingCircle(id)) {
      this.markSeenWhileFocused(id)
      return
    }

    this.addUnread(id, { announce: true })
  }

  isActivelyViewingCircle(circleId) {
    const id = Number(circleId)
    const selectedId = Number(this.selectedCircleIdValue)
    return id === selectedId && !tabIsHidden() && document.hasFocus()
  }

  shouldSilenceUnreadForCircle(circleId) {
    const id = Number(circleId)
    return id > 0 && id === Number(this.seenWhileFocusedCircleId)
  }

  markSeenWhileFocused(circleId) {
    const id = Number(circleId)
    if (!id || !this.isActivelyViewingCircle(id)) return

    this.seenWhileFocusedCircleId = id
    this.markCircleReadOnServer(id)
  }

  markCircleReadOnServer(circleId) {
    const id = Number(circleId)
    if (!id) return

    fetch("/user_profile/mark_circle_read", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: JSON.stringify({ circle_id: id })
    }).catch(() => {
      // The next poll or focus event can retry.
    })
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  addUnread(circleId, { announce = false } = {}) {
    const id = Number(circleId)
    if (!id) return

    const isNew = !this.unreadIds.has(id)
    this.unreadIds.add(id)

    if (announce && isNew) {
      this.alertBlip?.play()
    }

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
    const tabIsVisible = !tabIsHidden()
    let count = 0

    this.unreadIds.forEach((id) => {
      if (id === selectedId && tabIsVisible) return
      count++
    })

    return count
  }

  updateTabBadge() {
    const count = this.tabNotificationCount()
    this.tabAlerts?.update(count)
  }

  handleVisibilityChange = () => {
    if (tabIsHidden()) {
      this.tabWasInactive = true
      hiddenPoll.start(this)
      return
    }

    hiddenPoll.stop()
    this.handleTabReturned()
  }

  handleWindowBlur = () => {
    this.tabWasInactive = true
  }

  handleWindowFocus = () => {
    if (tabIsHidden()) return
    if (!this.tabWasInactive) return

    hiddenPoll.stop()
    this.handleTabReturned()
  }

  handlePageShow = (event) => {
    if (!event.persisted) return
    hiddenPoll.stop()
    this.handleTabReturned()
  }

  handleTabReturned = async () => {
    if (this.tabReturnInFlight) return
    this.tabReturnInFlight = true

    const hadUnreadAlerts = this.tabNotificationCount() > 0

    try {
      hiddenPoll.stop()
      this.processBridgeEvents()

      await this.resyncSquakFeed()

      if (this.tabWasInactive) {
        await this.fetchUnreadAlerts()
      }

      this.dismissUnreadForSelectedCircle()
      this.syncUnreadUi()
      this.updateTabBadge()

      // Browsers block audio in background tabs, so blip once when returning with unreads.
      if (this.tabWasInactive && (hadUnreadAlerts || this.tabNotificationCount() > 0)) {
        this.alertBlip?.play()
      }
    } finally {
      this.tabReturnInFlight = false
      this.tabWasInactive = false
    }
  }

  async resyncSquakFeed() {
    const circleId = Number(this.selectedCircleIdValue)
    if (!circleId || this.resyncingFeed) return

    this.resyncingFeed = true
    try {
      const resp = await fetch(`/squaks/${circleId}`, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin",
        cache: "no-store"
      })

      if (!resp.ok) return

      const html = await resp.text()
      if (html && html.includes("<turbo-stream")) {
        Turbo.renderStreamMessage(html)
      }
    } catch (_) {
      // Keep the current feed; the next focus/visibility event can retry.
    } finally {
      this.resyncingFeed = false
    }
  }

  async fetchUnreadAlerts() {
    if (!tabIsHidden()) {
      stopHiddenPolling()
      return
    }

    try {
      const resp = await fetch("/user_profile/unread_alerts", {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        cache: "no-store",
        signal: hiddenPoll.nextAbortSignal()
      })

      if (!resp.ok) return

      const data = await resp.json()
      this.applyUnreadIds(data.unread_circle_ids)
    } catch (error) {
      if (error?.name === "AbortError") return
      // Retry on the next hidden-tab poll.
    }
  }

  applyUnreadIds(ids) {
    const prev = this.unreadIds
    const next = new Set((ids || []).map((id) => Number(id)))

    if (this.seenWhileFocusedCircleId) {
      next.delete(Number(this.seenWhileFocusedCircleId))
    }

    next.forEach((id) => {
      if (!prev.has(id) && !this.shouldSilenceUnreadForCircle(id)) {
        this.alertBlip?.play()
      }
    })

    this.unreadIds = next

    if (!tabIsHidden()) {
      this.dismissUnreadForSelectedCircle()
    }

    this.syncUnreadUi()
    this.updateTabBadge()
  }
}