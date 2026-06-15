import {Controller} from "@hotwired/stimulus"
import "trix"
import {getClipboardImageItems, getPastedText, isUrl, extractTypedUrls, turboSubmitSucceeded} from "trix_paste_utils"

export default class extends Controller {
  static TYPED_URL_DEBOUNCE_MS = 500

  connect() {
    this.trixEl = this.element.tagName === "TRIX-EDITOR"
      ? this.element
      : this.element.querySelector("trix-editor")

    if (!this.trixEl) {
      console.warn("[paste_url] No <trix-editor> found to bind paste handlers")
      return
    }

    this.seenUrls = new Set()
    this.form = this.element.closest("form")

    this.onPaste = this.handlePaste.bind(this)
    this.onPasteCapture = (event) => {
      const targetEditor = event.target?.closest?.("trix-editor")
      if (!targetEditor || targetEditor !== this.trixEl) return
      this.onPaste(event)
    }

    this.onTrixChange = this.scheduleTypedUrlScan.bind(this)
    this.onTurboSubmitEnd = this.onTurboSubmitEnd.bind(this)

    window.addEventListener("paste", this.onPasteCapture, true)
    this.trixEl.addEventListener("trix-paste", this.onPaste)
    this.trixEl.addEventListener("trix-change", this.onTrixChange)

    if (this.form) {
      this.form.addEventListener("turbo:submit-end", this.onTurboSubmitEnd)
    }
  }

  disconnect() {
    if (this.onPasteCapture) {
      window.removeEventListener("paste", this.onPasteCapture, true)
    }
    if (this.trixEl) {
      if (this.onPaste) this.trixEl.removeEventListener("trix-paste", this.onPaste)
      if (this.onTrixChange) this.trixEl.removeEventListener("trix-change", this.onTrixChange)
    }
    if (this.form && this.onTurboSubmitEnd) {
      this.form.removeEventListener("turbo:submit-end", this.onTurboSubmitEnd)
    }
    if (this._typedUrlScanTimer) {
      clearTimeout(this._typedUrlScanTimer)
    }
  }

  onTurboSubmitEnd(event) {
    if (turboSubmitSucceeded(event)) {
      this.seenUrls = new Set()
    }
  }

  scheduleTypedUrlScan() {
    if (this._typedUrlScanTimer) {
      clearTimeout(this._typedUrlScanTimer)
    }

    this._typedUrlScanTimer = setTimeout(() => {
      this._typedUrlScanTimer = null
      this.scanTypedUrls()
    }, this.constructor.TYPED_URL_DEBOUNCE_MS)
  }

  scanTypedUrls() {
    const editor = this.editor
    if (!editor || this._enhancingUrl) return

    const text = editor.getDocument().toString()
    const matches = extractTypedUrls(text)

    for (const {urlText, start, end} of matches) {
      const normalized = this.normalizeUrl(urlText)
      if (this.seenUrls.has(normalized)) continue
      if (this.isPreviewOrAttachmentAt(start)) continue

      this.enhanceUrlAtRange(urlText, normalized, start, end)
      return
    }
  }

  isPreviewOrAttachmentAt(position) {
    const piece = this.editor.getDocument().getPieceAtPosition(position)
    if (!piece) return false
    return typeof piece.isAttachment === "function" && piece.isAttachment()
  }

  async enhanceUrlAtRange(urlText, normalizedUrl, start, end) {
    const editor = this.editor
    if (!editor) return

    this.seenUrls.add(normalizedUrl)
    this._enhancingUrl = true

    try {
      const piece = editor.getDocument().getPieceAtPosition(start)
      const href = piece?.getAttribute?.("href")

      if (href !== normalizedUrl) {
        editor.setSelectedRange([start, end])
        editor.activateAttribute("href", normalizedUrl)
        editor.setSelectedRange([end, end])
      }

      await this.replaceRangeWithPreview({urlText, normalizedUrl, start, end})
    } catch (error) {
      this.seenUrls.delete(normalizedUrl)
      console.error("Failed to enhance typed URL:", error)
    } finally {
      this._enhancingUrl = false
    }
  }

  handlePaste(event) {
    if (event.__handled) return
    if (getClipboardImageItems(event).length > 0) return

    const text = getPastedText(event).trim()
    if (!isUrl(text)) return

    event.preventDefault()
    event.__handled = true
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation()
    }

    const normalized = this.normalizeUrl(text)
    this.seenUrls.add(normalized)
    this.insertBasicLink(text, normalized)
    this.replaceRangeWithPreview({
      urlText: text,
      normalizedUrl: normalized,
      start: this.editor.getPosition() - text.length,
      end: this.editor.getPosition()
    })
  }

  insertBasicLink(pastedText, normalizedUrl) {
    const editor = this.editor

    editor.insertString(pastedText)

    const endPosition = editor.getPosition()
    const startPosition = endPosition - pastedText.length

    editor.setSelectedRange([startPosition, endPosition])
    editor.activateAttribute("href", normalizedUrl)
    editor.setSelectedRange([endPosition, endPosition])
  }

  async replaceRangeWithPreview({urlText, normalizedUrl, start, end}) {
    const editor = this.editor

    let data = null

    try {
      const response = await fetch(`/api/v1/metadata?url=${encodeURIComponent(normalizedUrl)}`)
      data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || "Metadata fetch failed")
      }
    } catch (error) {
      console.warn("Metadata unavailable, using text-only preview:", error)
      data = {type: "link", url: normalizedUrl, title: normalizedUrl}
    }

    const currentHref = editor.getDocument().getPieceAtPosition(start)?.getAttribute("href")
    if (currentHref !== normalizedUrl) {
      console.warn("Content changed - skipping replacement")
      return
    }

    const content = this.buildPreviewContent(data)
    if (!content) return

    editor.setSelectedRange([start, end])
    editor.deleteInDirection("backward")
    editor.insertAttachment(new Trix.Attachment({
      content: content,
      contentType: "text/html"
    }))
  }

  buildPreviewContent(data) {
    if (data.type === "youtube") {
      return this.buildYoutubeContent(data)
    }

    return this.buildLinkContent(data)
  }

  buildYoutubeContent(data) {
    const title = this.escapeAttr(data.title || "YouTube Video")
    const url = this.escapeAttr(data.url)
    const thumbnail = data.thumbnail || data.image

    if (!thumbnail) {
      return this.buildLinkContent(data)
    }

    const visitHint = `<div class="link-preview-youtube-hint">click to watch on YouTube</div>`

    return `
      <a href="${url}" target="_blank" rel="noopener noreferrer" class="link-preview-youtube">
        <span class="link-preview-youtube-thumb">
          <img src="${this.escapeAttr(thumbnail)}" alt="${title}" class="link-preview-thumbnail link-preview-thumbnail--wide">
          <span class="link-preview-youtube-badge" aria-hidden="true"></span>
        </span>
        ${visitHint}
      </a>`
  }

  buildLinkContent(data) {
    const url = this.escapeAttr(data.url)
    const title = this.linkTitle(data)
    const thumbnail = data.thumbnail || data.image
    const siteName = data.site_name
      ? `<div class="text-muted small">${this.escapeHtml(data.site_name)}</div>`
      : ""
    const desc = data.desc
      ? `<div class="small mt-1">${this.escapeHtml(data.desc)}</div>`
      : ""

    const visitHint = `<div class="link-preview-visit-hint">click link to visit site</div>`

    if (!thumbnail) {
      return `
        <div class="link-preview card link-preview--text-only">
          <div class="card-body py-2">
            <a href="${url}" target="_blank" rel="noopener noreferrer" class="card-title h6 mb-0">${title}</a>
            ${visitHint}
            ${siteName}
            ${desc}
          </div>
        </div>`
    }

    return `
      <div class="link-preview card my-2 w-100">
        <div class="row g-0 align-items-center">
          <div class="col-auto">
            <img src="${this.escapeAttr(thumbnail)}" alt="" class="img-thumbnail link-preview-thumbnail">
          </div>
          <div class="col">
            <div class="card-body py-2">
              <a href="${url}" target="_blank" rel="noopener noreferrer" class="card-title h6 d-block mb-1">${title}</a>
              ${visitHint}
              ${siteName}
              ${desc}
            </div>
          </div>
        </div>
      </div>`
  }

  linkTitle(data) {
    const title = data.title
    if (title && title !== "Untitled" && title.trim().length > 0) {
      return this.escapeHtml(title)
    }
    return this.escapeHtml(data.url)
  }

  normalizeUrl(text) {
    if (text.match(/^https?:\/\//i)) {
      return text
    }

    return `https://${text}`
  }

  escapeHtml(value) {
    return String(value || "").replace(/[&<>"']/g, (char) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    })[char])
  }

  escapeAttr(value) {
    return this.escapeHtml(value)
  }

  get editor() {
    return this.trixEl?.editor || this.element.editor
  }
}