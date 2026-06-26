import {Controller} from "@hotwired/stimulus"
import "trix"
import {getClipboardImageItems, getPastedText, isUrl, extractTypedUrls, turboSubmitSucceeded} from "trix_paste_utils"

export default class extends Controller {
  static TYPED_URL_DEBOUNCE_MS = 250

  connect() {
    this.trixEl = this.element.tagName === "TRIX-EDITOR"
      ? this.element
      : this.element.querySelector("trix-editor")

    if (!this.trixEl) {
      console.warn("[paste_url] No <trix-editor> found to bind paste handlers")
      return
    }

    this.seenUrls = new Set()
    this.pendingPreviews = new Map()
    this.form = this.element.closest("form")

    this.onPaste = this.handlePaste.bind(this)
    this.onPasteCapture = (event) => {
      const targetEditor = event.target?.closest?.("trix-editor")
      if (!targetEditor || targetEditor !== this.trixEl) return
      this.onPaste(event)
    }

    this.onTrixChange = this.scheduleTypedUrlScan.bind(this)
    this.onTurboSubmitEnd = this.onTurboSubmitEnd.bind(this)
    this.onEditorClearing = this.onEditorClearing.bind(this)
    this.onEditorCleared = this.onEditorCleared.bind(this)

    window.addEventListener("paste", this.onPasteCapture, true)
    this.trixEl.addEventListener("trix-paste", this.onPaste)
    this.trixEl.addEventListener("trix-change", this.onTrixChange)

    if (this.form) {
      this.form.addEventListener("turbo:submit-end", this.onTurboSubmitEnd)
      this.form.addEventListener("squak:editor-clearing", this.onEditorClearing)
      this.form.addEventListener("squak:editor-cleared", this.onEditorCleared)
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
    if (this.form) {
      if (this.onTurboSubmitEnd) {
        this.form.removeEventListener("turbo:submit-end", this.onTurboSubmitEnd)
      }
      if (this.onEditorClearing) {
        this.form.removeEventListener("squak:editor-clearing", this.onEditorClearing)
      }
      if (this.onEditorCleared) {
        this.form.removeEventListener("squak:editor-cleared", this.onEditorCleared)
      }
    }
    if (this._typedUrlScanTimer) {
      clearTimeout(this._typedUrlScanTimer)
    }
  }

  onTurboSubmitEnd(event) {
    if (!turboSubmitSucceeded(event)) return

    this.cancelTypedUrlScan()
    this.seenUrls = new Set()
    this.pendingPreviews = new Map()
    this._enhancingUrl = false
  }

  onEditorClearing() {
    this._suppressUrlScan = true
    this.cancelTypedUrlScan()
  }

  onEditorCleared() {
    this._suppressUrlScan = false
    this.seenUrls = new Set()
    this.pendingPreviews = new Map()
    this._enhancingUrl = false
  }

  cancelTypedUrlScan() {
    if (this._typedUrlScanTimer) {
      clearTimeout(this._typedUrlScanTimer)
      this._typedUrlScanTimer = null
    }
  }

  scheduleTypedUrlScan() {
    if (this._suppressUrlScan) return

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
    if (this.pendingPreviews.has(position)) return true

    const piece = this.editor.getDocument().getPieceAtPosition(position)
    if (!piece) return false

    return this.isAttachmentPiece(piece) &&
      this.attachmentHtml(piece).includes("link-preview")
  }

  isAttachmentPiece(piece) {
    return Boolean(piece?.attachment)
  }

  attachmentHtml(piece) {
    return piece?.attachment?.getContent?.() || ""
  }

  canStartPreview(normalizedUrl, position) {
    const piece = this.editor.getDocument().getPieceAtPosition(position)
    if (!piece || this.isAttachmentPiece(piece)) return false

    return piece.getAttribute?.("href") === normalizedUrl
  }

  previewStillPending(normalizedUrl, position) {
    return this.pendingPreviews.get(position) === normalizedUrl
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

    this.insertLoadingPreview(normalizedUrl, start, end)

    let data = null

    try {
      data = await this.fetchMetadata(normalizedUrl)
    } catch (error) {
      console.warn("Metadata unavailable, using text-only preview:", error)
      data = {type: "link", url: normalizedUrl, title: normalizedUrl}
    }

    data = this.normalizePreviewData(normalizedUrl, data)

    if (!this.previewStillPending(normalizedUrl, start)) {
      console.warn("Content changed - skipping replacement")
      return
    }

    const content = this.buildPreviewContent(data)
    if (!content) {
      this.pendingPreviews.delete(start)
      return
    }

    this.replacePreviewAt(start, content)
  }

  insertLoadingPreview(normalizedUrl, start, end) {
    const editor = this.editor
    if (this.pendingPreviews.has(start)) return
    if (!this.canStartPreview(normalizedUrl, start)) return

    this.pendingPreviews.set(start, normalizedUrl)

    const content = `
      <div class="link-preview card link-preview--loading my-2 w-100" aria-busy="true">
        <div class="card-body py-2 text-muted small">Loading preview...</div>
      </div>`

    editor.setSelectedRange([start, end])
    editor.deleteInDirection("backward")
    editor.insertAttachment(new Trix.Attachment({
      content: content,
      contentType: "text/html"
    }))
  }

  replacePreviewAt(start, content) {
    const editor = this.editor

    editor.setSelectedRange([start, start + 1])
    editor.deleteInDirection("backward")
    editor.insertAttachment(new Trix.Attachment({
      content: content,
      contentType: "text/html"
    }))
    this.pendingPreviews.delete(start)
  }

  async fetchMetadata(normalizedUrl, { allowRetry = true } = {}) {
    const requestUrl = `/api/v1/metadata?url=${encodeURIComponent(normalizedUrl)}&_=${Date.now()}`
    const response = await fetch(requestUrl, {
      cache: "no-store",
      headers: {Accept: "application/json"},
      credentials: "same-origin"
    })
    const data = await response.json()

    if (!response.ok || data.error) {
      throw new Error(data.error || "Metadata fetch failed")
    }

    if (this.isTweetStatusUrl(normalizedUrl) && data.type === "link") {
      if (allowRetry) {
        return this.fetchMetadata(normalizedUrl, {allowRetry: false})
      }
      throw new Error("Received stale generic link preview for an X status URL")
    }

    return data
  }

  normalizePreviewData(normalizedUrl, data) {
    if (!data || data.type === "tweet" || data.type === "youtube") return data
    if (!this.isTweetStatusUrl(normalizedUrl)) return data

    const thumbnail = data.thumbnail || data.image
    if (!thumbnail || thumbnail.includes("profile_images")) return data

    return {
      ...data,
      type: "tweet",
      text: data.text || data.desc,
      thumbnail: thumbnail,
      media_type: this.inferTweetMediaType(thumbnail)
    }
  }

  inferTweetMediaType(thumbnail) {
    if (thumbnail.includes("ext_tw_video_thumb") || thumbnail.includes("amplify_video_thumb")) {
      return "video"
    }
    if (thumbnail.includes("pbs.twimg.com/media/")) {
      return "photo"
    }
    return undefined
  }

  isTweetStatusUrl(url) {
    return /(?:twitter\.com|x\.com)\/(?:[^/]+\/)?status\/\d+/i.test(String(url || ""))
  }

  buildPreviewContent(data) {
    if (data.type === "youtube") {
      return this.buildYoutubeContent(data)
    }

    if (data.type === "tweet") {
      return this.buildTweetContent(data)
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

  buildTweetContent(data) {
    const url = this.escapeAttr(data.url)
    const authorLabel = data.title || "Post on X"
    const {name: authorName, handle: authorHandle} = this.parseTweetAuthor(authorLabel)
    const thumbnail = data.thumbnail || data.image
    const visitHint = `<div class="link-preview-tweet-hint">click to view on X</div>`
    const header = this.buildTweetHeader(data.author_avatar, authorName, authorHandle)
    const tweetTitle = data.text
      ? `<div class="link-preview-tweet-title">${this.escapeHtml(data.text)}</div>`
      : `<div class="link-preview-tweet-title">${this.escapeHtml(authorLabel)}</div>`
    const authorLine = data.text && !header
      ? `<div class="link-preview-tweet-author">${this.escapeHtml(authorLabel)}</div>`
      : ""

    if (thumbnail && data.media_type === "video") {
      const duration = this.formatDuration(data.duration_ms)
      const durationBadge = duration
        ? `<span class="link-preview-tweet-duration">${this.escapeHtml(duration)}</span>`
        : ""

      return `
        <a href="${url}" target="_blank" rel="noopener noreferrer" class="link-preview-tweet link-preview-tweet--video">
          <div class="link-preview-tweet-card">
            ${header}
            ${tweetTitle}
            <div class="link-preview-tweet-thumb">
              <img src="${this.escapeAttr(thumbnail)}" alt="" class="link-preview-tweet-thumbnail">
              <span class="link-preview-tweet-play-badge" aria-hidden="true"></span>
              ${durationBadge}
            </div>
            ${visitHint}
          </div>
        </a>`
    }

    if (thumbnail) {
      return `
        <a href="${url}" target="_blank" rel="noopener noreferrer" class="link-preview-tweet">
          <div class="link-preview-tweet-card">
            ${header}
            <div class="link-preview-tweet-thumb">
              <img src="${this.escapeAttr(thumbnail)}" alt="" class="link-preview-tweet-thumbnail">
            </div>
            ${tweetTitle}
            ${authorLine}
            ${visitHint}
          </div>
        </a>`
    }

    return `
      <div class="link-preview card link-preview--tweet link-preview--text-only">
        <div class="card-body py-2">
          ${header}
          ${tweetTitle}
          ${authorLine}
          ${visitHint}
        </div>
      </div>`
  }

  buildTweetHeader(avatarUrl, authorName, authorHandle) {
    if (!avatarUrl) return ""

    const handleLine = authorHandle
      ? `<span class="link-preview-tweet-handle">@${this.escapeHtml(authorHandle)}</span>`
      : ""

    return `
      <div class="link-preview-tweet-header">
        <img src="${this.escapeAttr(avatarUrl)}" alt="" class="link-preview-tweet-avatar">
        <div class="link-preview-tweet-header-text">
          <span class="link-preview-tweet-name">${this.escapeHtml(authorName)}</span>
          ${handleLine}
        </div>
      </div>`
  }

  parseTweetAuthor(label) {
    const match = String(label || "").match(/^(.+?)\s+\(@([^)]+)\)$/)
    if (!match) {
      return {name: label || "Post on X", handle: ""}
    }

    return {name: match[1].trim(), handle: match[2].trim()}
  }

  formatDuration(durationMs) {
    const ms = Number(durationMs)
    if (!Number.isFinite(ms) || ms <= 0) return ""

    const totalSeconds = Math.round(ms / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60

    if (minutes > 0) {
      return `${minutes}:${String(seconds).padStart(2, "0")}`
    }

    return `0:${String(seconds).padStart(2, "0")}`
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