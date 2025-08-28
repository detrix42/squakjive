import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["squakEditor", "circleId", "html", "previews"]

  static values = {
    circleId: Number
  }

  initialize() {
    console.log('squak editor initializing')
    // Register underline once
    if (window.Trix && !Trix.config.textAttributes.underline) {
      console.log('registering underline')
      Trix.config.textAttributes.underline = {
        tagName: "u",
        inheritable: true,
        parser: el => el.tagName === "U" || el.style?.textDecoration?.includes("underline")
      }
    }

    this.insertUnderlineIntoToolbar = (toolbarElement) => {
      if (!toolbarElement) return
      const group = toolbarElement.querySelector(".trix-button-group--text-tools")
      if (!group || group.querySelector(".trix-button--icon-underline")) return

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "trix-button trix-button--icon trix-button--icon-underline"
      btn.setAttribute("data-trix-attribute", "underline")
      btn.setAttribute("data-trix-key", "u")
      btn.setAttribute("aria-label", "Underline")
      btn.setAttribute("title", "Underline")
      btn.setAttribute("tabindex", "-1")

      // Place after Italic if present
      const italicBtn = group.querySelector('[data-trix-attribute="italic"]')
      if (italicBtn) {
        const afterItalic = italicBtn.nextSibling
        if (afterItalic) {
          group.insertBefore(btn, afterItalic)
        } else {
          group.appendChild(btn)
        }
      } else {
        group.appendChild(btn)
      }
    }

    // Bound event handlers so we can remove them later
    this.onToolbarSetup = (event) => {
      // Some builds dispatch detail.toolbarElement; others pass toolbarElement on the event object
      const toolbar = event.detail?.toolbarElement || event.toolbarElement
      if (!toolbar) return
      console.log('toolbar setup event caught')
      this.insertUnderlineIntoToolbar(toolbar)
    }

    this.onTrixInitialize = (event) => {
      // trix-initialize fires on the editor element
      const editorEl = event.target
      const toolbar = editorEl && editorEl.toolbarElement
      if (!toolbar) return
      console.log('trix initialize event caught')
      this.insertUnderlineIntoToolbar(toolbar)
    }
  }

  connect() {
    console.log("Squakeditor controller connected")

    // Attach listeners (do this in connect so they are reattached on Turbo visits)
    document.addEventListener("trix-toolbar-setup", this.onToolbarSetup)
    document.addEventListener("trix-initialize", this.onTrixInitialize)

    // Immediate pass for already-present toolbars (covers SSR or late binding)
    document.querySelectorAll("trix-toolbar").forEach((tb) => {
      this.insertUnderlineIntoToolbar(tb)
    })

    this.element.addEventListener("trix-attachment-add", (event) => {
      const { attachment } = event;
      if (attachment.file) {
        this.uploadAttachment(attachment);
      }
    });

    // Optional: File validation
    this.element.addEventListener("trix-file-accept", (event) => {
      const { file } = event;
      if (file.size > 100 * 1024 * 1024) {
        event.preventDefault();
        alert("File too large!");
      }
    });


  }

  uploadAttachment(attachment) {
    const file = attachment.file;
    const formData = new FormData();
    formData.append("Content-Type", file.type);
    formData.append("attachment[file]", file);

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/attachments", true);
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector('meta[name="csrf-token"]').content);

    xhr.upload.onprogress = (event) => {
      const progress = (event.loaded / event.total) * 100;
      attachment.setUploadProgress(progress);
    };

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        const data = JSON.parse(xhr.responseText);
        let attributes = { href: data.url }; // Base for all

        if (data.content_type.startsWith("image/")) {
          attributes.url = data.url; // Trix handles <img> preview
        } else if (data.content_type.startsWith("video/")) {
          attributes.content = `<figure class="attachment attachment--preview attachment--${data.filename.split('.').pop()}"><video src="${data.url}" controls width="100%" height="auto"></video><figcaption>${data.filename}</figcaption></figure>`;
        } else {
          attributes.content = `<figure class="attachment attachment--file"><a href="${data.url}">${data.filename} (${data.content_type})</a></figure>`;
        }

        attachment.setAttributes(attributes);
      } else {
        attachment.remove();
        alert("Upload failed!");
      }
    };

    xhr.send(formData);
  }


  disconnect() {
    // Remove toolbar listener to prevent duplicates on reconnection
    if (this.onToolbarSetup) {
      document.removeEventListener("trix-toolbar-setup", this.onToolbarSetup)
    }


    if (this.hasSquakEditorTarget) {

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
      // Always ensure it’s linkified immediately
      this.linkifyUrlInEditor(url, url)

      // Then fetch preview once
      if (!this.seenUrls) this.seenUrls = new Set()
      if (this.seenUrls.has(url)) return
      this.seenUrls.add(url)
      this.fetchPreview(url)
    })

  }

  extractUrls(text) {
    if (!text) return []

    // Basic http/https URL regex
    const re = /\bhttps?:\/\/[^\s<>"')]+/gi
    const matches = Array.from(text.matchAll(re)).map((m) => this.normalizeUrlText(m[0]))

    return [...new Set(matches.filter(Boolean))]

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

  // Replace your linkifyUrlInEditor with this corrected version
linkifyUrlInEditor(url, title) {
  const normalized = this.normalizeUrlText(url)
  if (!normalized) return

  // 1) Correct existing-anchor check: compare to normalized
  const existing = Array.from(this.squakEditorTarget.querySelectorAll("a"))
    .find(a => (a.getAttribute("href") || "") === normalized)
  if (existing) {
    // If we have a title and the current text is the raw URL, replace it
    const safeTitle = (title || "").toString().trim()
    if (safeTitle && existing.textContent.trim() === normalized) {
      existing.textContent = safeTitle
    }
    return
  }


  const walker = document.createTreeWalker(this.squakEditorTarget, NodeFilter.SHOW_TEXT, null)
  const urlRe = new RegExp(this.escapeForRegex(normalized))

  let node
  while ((node = walker.nextNode())) {
    const txt = node.nodeValue
    if (!txt) continue

    let idx = txt.search(urlRe)
    if (idx === -1) {
      const withPunct = new RegExp(this.escapeForRegex(normalized) + "[)\\]\\}.,!?\"'“”’]*")
      idx = txt.search(withPunct)
    }
    if (idx !== -1) {
      const after = txt.slice(idx)
      const m = after.match(new RegExp("^" + this.escapeForRegex(normalized)))
      const matchLen = m ? m[0].length : normalized.length

      const anchor = document.createElement("a")
      anchor.href = normalized
      anchor.textContent = title || normalized
      anchor.target = "_blank"
      anchor.rel = "noopener noreferrer"

      const range = document.createRange()
      range.setStart(node, idx)
      range.setEnd(node, idx + matchLen)
      range.deleteContents()
      range.insertNode(anchor)

      const sel = window.getSelection()
      if (sel) {
        sel.removeAllRanges()
        const caret = document.createRange()
        caret.setStartAfter(anchor)
        caret.setEndAfter(anchor)
        sel.addRange(caret)
      }
      return
    }
  }

  // 2) Fallback appended only after we've searched all nodes
  const fallback = document.createElement("a")
  fallback.href = normalized
  fallback.textContent = title || normalized
  fallback.target = "_blank"
  fallback.rel = "noopener noreferrer"
  this.squakEditorTarget.appendChild(fallback)
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

  // 1) Robust escape for building a RegExp from a literal URL
  escapeForRegex(s) {
    return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }

// 2) Normalize URLs: trim whitespace and trailing punctuation that
// commonly attaches in typing (.,),],},!,"', etc.)
  normalizeUrlText(raw) {
    if (!raw) return ""
    let url = raw.trim()

    // strip common trailing punctuation that may be typed accidentally
    url = url.replace(/[)\]\}.,!?'"“”’]+$/, "")


    // Strip trailing punctuation while keeping a balanced closing parenthesis case
    // Example: https://x.com/foo) -> keep ) only if there is a matching (
    const trailing = /[)\]\}.,!?'"“”’]+$/

    if (trailing.test(url)) {
      // Preserve a trailing ")" if there are more "(" than ")"
      const closes = (url.match(/\)/g) || []).length
      const opens  = (url.match(/\(/g) || []).length
      url = url.replace(trailing, (punct) => {
        if (punct === ")" && opens > closes - 1) return ")" // keep one ")"
        return "" // otherwise drop trailing punctuation
      })
    }
    return url
  }


}
