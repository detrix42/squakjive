import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel"]

  static values = {
    circleId: Number,
    limit: Number
  }

  connect() {
    console.log("Squak index controller connected. Squaks for circle:", this.circleIdValue)

    // This controller is attached to the <ul>, so use this.element as the list
    this.listEl = this.element

    this.loading = false
    this.done = false
    this.observing = false

    // If the list is empty, nothing to paginate
    if (!this.lastItemEl()) {
      this.done = true
      this.hideSentinel()
      return
    }

    // Prepare the observer but do NOT observe yet (to avoid auto-drain on first paint)
    this.observer = new IntersectionObserver(
        entries => entries.forEach(entry => { if (entry.isIntersecting) this.loadMore() }),
        {
          root: null,
          rootMargin: "200px",
          threshold: 0.01
        }
    )

    // Start observing only after user scrolls (once)
    this._startObserving = this.startObserving.bind(this)
    window.addEventListener("wheel", this._startObserving, { passive: true, once: true })
    window.addEventListener("touchstart", this._startObserving, { passive: true, once: true })
    window.addEventListener("pointerdown", this._startObserving, { passive: true, once: true })



  }

  disconnect() {
    if (this.observer && this.hasSentinelTarget) {
      this.observer.unobserve(this.sentinelTarget)
    }
  }

  startObserving() {
    if (this.hasSentinelTarget && this.observer && !this.observing && !this.done) {
      this.observer.observe(this.sentinelTarget)
      this.observing = true
    }
  }


  lastItemEl() {
    const items = this.listEl?.querySelectorAll("[data-squak-id]")
    return items && items.length ? items[items.length - 1] : null
  }

  async loadMore() {
    if (this.loading || this.done) return
    if (!this.listEl) return

    console.log('loading more squaks')

    const last = this.lastItemEl()
    if (!last) {
      this.done = true
      this.hideSentinel()
      return
    }

    const beforeId = last.getAttribute("data-squak-id")
    const limit = this.hasLimitValue ? this.limitValue : 20
    const circleId = this.circleIdValue

    // Temporarily stop observing to avoid repeated triggers while loading
    if (this.observer && this.hasSentinelTarget && this.observing) {
      this.observer.unobserve(this.sentinelTarget)
      this.observing = false
    }

    this.loading = true
    try {
      const resp = await fetch(
          `/squaks/${circleId}?before_id=${encodeURIComponent(beforeId)}&limit=${encodeURIComponent(limit)}`,
          {
            headers: { Accept: "text/vnd.turbo-stream.html" },
            credentials: "same-origin",
          }
      )

      if (!resp.ok) {
        // Treat 204/404 as end-of-list
        if (resp.status === 204 || resp.status === 404) {
          this.done = true
          this.hideSentinel()
          return
        }
        throw new Error(`HTTP ${resp.status}`)
      }

      const html = await resp.text()

      if (html && html.includes("<turbo-stream")) {
        // IMPORTANT: apply the Turbo Stream response
        Turbo.renderStreamMessage(html)

        // IMPORTANT: do NOT re-observe immediately; wait for the next user interaction.
        // This ensures only one page loads per scroll.
        const rearm = () => {
          window.removeEventListener("wheel", rearm)
          window.removeEventListener("touchstart", rearm)
          window.removeEventListener("pointerdown", rearm)
          if (this.observer && this.hasSentinelTarget && !this.done) {
            this.observer.observe(this.sentinelTarget)
            this.observing = true
          }
        }
        window.addEventListener("wheel", rearm, { passive: true, once: true })
        window.addEventListener("touchstart", rearm, { passive: true, once: true })
        window.addEventListener("pointerdown", rearm, { passive: true, once: true })
      } else {
        // No stream content -> end
        this.done = true
        this.hideSentinel()
      }


      // Otherwise, Turbo will process and append automatically
    } catch (e) {
      // On error, stop further attempts
      this.done = true
      this.hideSentinel()
    } finally {
      this.loading = false
    }
  }

  hideSentinel() {
    if (this.hasSentinelTarget) this.sentinelTarget.classList.add("d-none")
  }


}
