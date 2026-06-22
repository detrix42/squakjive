// Keeps inactive-tab alerts visible the way Discord/Slack do:
// 1) document.title prefix  (works in background, but easy to miss)
// 2) favicon badge overlay  (the red dot users actually notice on the tab strip)

const FAVICON_SIZE = 32
const BADGE_RADIUS = 9
const BADGE_X = 23
const BADGE_Y = 9

export class TabAlerts {
  constructor({ baseTitle, faviconSelector = 'link[rel="icon"][data-squakjive-brand-icon]' } = {}) {
    this.baseTitle = baseTitle || document.title.replace(/^\(\d+\)\s+/, "")
    this.faviconSelector = faviconSelector
    this.faviconLink = document.querySelector(faviconSelector)
    this.originalFaviconHref = this.faviconLink?.getAttribute("href") || null
    this.faviconImage = null
    this.faviconReady = this.prepareFavicon()
    this.lastCount = 0
    this.clearAppBadge()
  }

  async prepareFavicon() {
    if (!this.faviconLink || !this.originalFaviconHref) return false

    return new Promise((resolve) => {
      const image = new Image()
      image.onload = () => {
        this.faviconImage = image
        resolve(true)
      }
      image.onerror = () => resolve(false)
      image.src = this.originalFaviconHref
    })
  }

  async update(count) {
    const unread = Math.max(0, Number(count) || 0)
    this.lastCount = unread
    this.updateTitle(unread)
    await this.updateFavicon(unread)
  }

  async reset() {
    await this.update(0)
    await this.clearAppBadge()
  }

  updateTitle(count) {
    document.title = count > 0 ? `(${count}) ${this.baseTitle}` : this.baseTitle
  }

  async updateFavicon(count) {
    if (!this.faviconLink || !this.originalFaviconHref) return
    if (!(await this.faviconReady) || !this.faviconImage) {
      return
    }

    if (count <= 0) {
      this.faviconLink.href = this.originalFaviconHref
      return
    }

    const canvas = document.createElement("canvas")
    canvas.width = FAVICON_SIZE
    canvas.height = FAVICON_SIZE
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    ctx.drawImage(this.faviconImage, 0, 0, FAVICON_SIZE, FAVICON_SIZE)

    ctx.fillStyle = "#e33"
    ctx.beginPath()
    ctx.arc(BADGE_X, BADGE_Y, BADGE_RADIUS, 0, Math.PI * 2)
    ctx.fill()

    ctx.strokeStyle = "#fff"
    ctx.lineWidth = 2
    ctx.stroke()

    if (count > 0 && count < 10) {
      ctx.fillStyle = "#fff"
      ctx.font = "bold 12px system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText(String(count), BADGE_X, BADGE_Y + 1)
    }

    this.faviconLink.href = canvas.toDataURL("image/png")
  }

  async clearAppBadge() {
    if (!("clearAppBadge" in navigator)) return

    try {
      await navigator.clearAppBadge()
    } catch (_) {
      // Ignore; we only use the canvas favicon badge.
    }
  }
}