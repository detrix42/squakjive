import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["squakEditor", "circleId", "html", "previews"]

  static values = {
    circleId: Number
  }

  connect() {
    console.log("Squakeditor controller connected")

    // Prefer paragraphs over divs when pressing Enter
    try {
      document.execCommand("defaultParagraphSeparator", false, "p")
    } catch (_) {}

    this.seenUrls = new Set()
    // Initial sync if editor has preloaded content
    this.sync()

    // Keep track of selection so toolbar buttons work
    this.savedRange = null
    this.squakEditorTarget.addEventListener("keyup", this.saveSelection)
    this.squakEditorTarget.addEventListener("mouseup", this.saveSelection)
    this.squakEditorTarget.addEventListener("mouseleave", this.saveSelection)
    this.squakEditorTarget.addEventListener("blur", this.saveSelection)

    // Keep hidden input in sync
    this.squakEditorTarget.addEventListener("input", this.sync)
    this.squakEditorTarget.addEventListener("paste", () => {
      requestAnimationFrame(() => {
        this.sync()
        this.scanForUrlsDebounced()
      })
    })

    // Also scan as user types, but debounced
    this._debouncedScan = this.debounce(() => this.scanForUrls(), 400)
    this.squakEditorTarget.addEventListener("input", this._debouncedScan)


    // Clear previews on Turbo submit start
    this._boundOnSubmitStart = this.onSubmitStart.bind(this)
    this._boundOnSubmitEnd = this.onSubmitEnd.bind(this)

    const formEl = this.element.closest("form")
    if (formEl) {
      formEl.addEventListener("turbo:submit-start", this._boundOnSubmitStart)
      formEl.addEventListener("turbo:submit-end", this._boundOnSubmitEnd)
    }


  }

  disconnect() {
    if (this.hasSquakEditorTarget) {
      this.squakEditorTarget.removeEventListener("keyup", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("mouseup", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("mouseleave", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("blur", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("input", this._boundSync)

    }

    const formEl = this.element.closest("form")
    if (formEl) {
      formEl.removeEventListener("turbo:submit-start", this._boundOnSubmitStart)
      formEl.removeEventListener("turbo:submit-end", this._boundOnSubmitEnd)
    }
  }

  // Called before the request is sent
  onSubmitStart() {
    this.resetPreviews()
  }

  // Optional: also clear editor once submit finishes successfully
  onSubmitEnd(event) {
    // event.detail.success is true/false
    if (event.detail?.success) {
      if (this.hasSquakEditorTarget) this.squakEditorTarget.innerHTML = ""
      this.sync()
    }
  }


  format(event) {
    const cmd = event.currentTarget?.dataset?.format
    if (!cmd) return

    this.restoreSelection()
    this.squakEditorTarget.focus()
    document.execCommand(cmd, false, null)
    this.sync()

  }

  // Save current selection range
  saveSelection = () => {
    const sel = window.getSelection()
    if (sel && sel.rangeCount > 0) {
      this.savedRange = sel.getRangeAt(0)
    }
  }


  // Restore saved selection range
  restoreSelection = () => {
    if (!this.savedRange) return
    const sel = window.getSelection()
    if (!sel) return
    sel.removeAllRanges()
    sel.addRange(this.savedRange)
  }


  // Mirror editor HTML into hidden input for submission
  sync = () => {
    if (this.hasHtmlTarget && this.hasSquakEditorTarget) {
      this.htmlTarget.value = this.squakEditorTarget.innerHTML
    }
  }

  // URL detection and preview
  scanForUrlsDebounced() {
    if (this._debouncedScan) this._debouncedScan()
  }

  scanForUrls() {
    const text = this.squakEditorTarget.innerText || ""
    const urls = this.extractUrls(text)
    // console.log('scan for urls:', urls)

    urls.forEach((url) => {
      if (this.seenUrls.has(url)) return
      this.fetchPreview(url)
    })
  }

  extractUrls(text) {
    // Basic http/https URL regex
    const re = /\bhttps?:\/\/[^\s<>"')]+/gi
    return Array.from(text.matchAll(re)).map((m) => m[0])
  }

  // Fetch preview and update editor: linkify URL using title
  async fetchPreview(url) {
    try {
      const resp = await fetch(`/link_preview?url=${encodeURIComponent(url)}`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })
      if (!resp.ok) return
      const data = await resp.json()
      if (!data) return

      // 1) Render side preview card
      this.renderPreviewCard(url, data)

      // 2) Linkify the URL in the editor using the preview title
      const title = (data.title || url).toString().trim()
      this.linkifyUrlInEditor(url, title)

      this.seenUrls.add(url)
      this.sync()
    } catch (e) {
      console.warn("link preview error", e)
    }
  }

  // Replace first occurrence of the raw URL text in the editor with an <a>
  linkifyUrlInEditor(url, title) {
    // If already linked, skip (avoid CSS.escape; compare hrefs directly)
    const existing = Array.from(this.squakEditorTarget.querySelectorAll("a"))
        .find(a => (a.getAttribute("href") || "") === url)
    if (existing) return

    const walker = document.createTreeWalker(this.squakEditorTarget, NodeFilter.SHOW_TEXT, null)
    const anchor = document.createElement("a")
    anchor.href = url
    anchor.textContent = title
    anchor.target = "_blank"
    anchor.rel = "noopener noreferrer"

    const urlRe = new RegExp(this.escapeForRegex(url))
    let node
    while ((node = walker.nextNode())) {
      const idx = node.nodeValue.search(urlRe)
      if (idx !== -1) {
        const range = document.createRange()
        range.setStart(node, idx)
        range.setEnd(node, idx + url.length)
        range.deleteContents()
        range.insertNode(anchor)

        // Move caret after the anchor
        const sel = window.getSelection()
        if (sel) {
          sel.removeAllRanges()
          const after = document.createRange()
          after.setStartAfter(anchor)
          after.setEndAfter(anchor)
          sel.addRange(after)
        }
        return
      }
    }
    // Fallback if the URL text was split by formatting
    this.squakEditorTarget.appendChild(anchor)
    this.squakEditorTarget.appendChild(document.createTextNode(" "))
  }



  renderPreviewCard(url, data) {
    if (!this.hasPreviewsTarget) return

    const card = document.createElement("div")
    card.className = "link-preview card my-2 w-100"
    card.dataset.url = url

    card.innerHTML = `
      <div class="row g-0 align-items-center">
        ${data.image ? `
          <div class="col-auto">
            <img src="${this.escapeAttr(data.image)}" alt="" 
            class="img-thumbnail" style="max-width: 120px; max-height: 120px; 
            object-fit: cover;">
          </div>` : ""}
        <div class="col">
          <div class="card-body py-2">
            <a href="${this.escapeAttr(data.url || url)}" target="_blank" 
               rel="noopener noreferrer" class="card-title h6 d-block mb-1">
                ${this.escapeHtml(data.title || url)}
            </a>
            ${data.site_name ? `<div class="text-muted small">${this.escapeHtml(data.site_name)}</div>` : ""}
            ${data.desc ? `<div class="small mt-1">${this.escapeHtml(data.desc)}</div>` : ""}
          </div>
        </div>
      </div>
    `
    console.log('rendering preview card', this.previewsTarget)
    this.previewsTarget.appendChild(card)
  }

  // utils
  debounce(fn, delay) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn.apply(this, args), delay)
    }
  }
  escapeHtml(s) {
    return (s || "").replace(/[&<>"']/g, (c) => (
        { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
  }
  escapeAttr(s) {
    return this.escapeHtml(String(s || ""))
  }

// After you clear editor on submit or after receive, also reset seenUrls:
  resetPreviews() {
    if (this.hasPreviewsTarget) this.previewsTarget.innerHTML = ""
    this.seenUrls = new Set()
  }

  escapeForRegex(s) {
    return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }



}
