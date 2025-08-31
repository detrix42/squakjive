import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = []

  static values = {
    circleId: Number
  }

  initialize() {
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

    // Toolbar setup hooks
    this.onToolbarSetup = (event) => {
      const toolbar = event.detail?.toolbarElement || event.toolbarElement
      if (toolbar) this.insertUnderlineIntoToolbar(toolbar)
    }
    this.onTrixInitialize = (event) => {
      const toolbar = event.target?.toolbarElement
      if (toolbar) this.insertUnderlineIntoToolbar(toolbar)
    }

    // Debounced linkify on content changes
    this.onTrixChange = this.debounce(() => {
      const editor = this.element.editor
      if (!editor) return

      const [caret] = editor.getSelectedRange()
      const docText = editor.getDocument().toString()

      const hit = this.findLatestUrlEndingAtOrBefore(docText, caret)
      if (!hit) return

      // Skip if we've already processed this exact span
      this._seenLinks ||= new Set()
      const key = `${hit.start}-${hit.end}-${hit.url}`
      if (this._seenLinks.has(key)) return

      // If the selection is already part of a link with same href, skip
      if (this.rangeIsLinked(editor, hit.start, hit.end, hit.url)) {
        this._seenLinks.add(key)
        return
      }

      // Linkify with visible text = URL first
      this.replaceRangeWithLink(editor, hit.start, hit.end, hit.url, hit.url)
      this._seenLinks.add(key)

      // Optional: upgrade visible text to a fetched title shortly after
      this.fetchTitle(hit.url).then((title) => {
        const safeTitle = (title || "").trim()
        if (!safeTitle || safeTitle === hit.url) return
        // Best-effort: re-apply at the original span
        // If the doc shifted heavily, this may miss; acceptable for quick follow-up
        this.replaceRangeWithLink(editor, hit.start, hit.start + safeTitle.length, hit.url, safeTitle)
      }).catch(() => {})
    }, 250)

    this.onAttachmentAdd = (event) => {
      const { attachment } = event
      if (attachment.file) this.uploadAttachment(attachment)
    }

    this.onFileAccept = (event) => {
      const { file } = event
      if (file.size > 100 * 1024 * 1024) {
        event.preventDefault()
        alert("File too large!")
      }
    }
  }

  connect() {
    console.log("Squakeditor controller connected")

    // Where to append signed_id inputs. We reuse the same container as paste_image_controller.
    this.form = this.element.closest("form")
    this.signedIdsContainer = this.form?.querySelector('[data-paste-image-target="signedIds"]')



    // Attach listeners (do this in connect so they are reattached on Turbo visits)
    document.addEventListener("trix-toolbar-setup", this.onToolbarSetup)
    document.addEventListener("trix-initialize", this.onTrixInitialize)

    // Immediate pass for already-present toolbars (covers SSR or late binding)
    document.querySelectorAll("trix-toolbar").forEach((tb) => {
      this.insertUnderlineIntoToolbar(tb)
    })

    this.element.addEventListener("trix-change", this.onTrixChange)

    this._blockActionTextUpload = (event) => {
      const att = event.attachment
      if (att && att.file) {
        event.preventDefault()
        event.stopImmediatePropagation()
        console.debug("[squakeditor] Blocked ActionText upload for:", att.file.name, att.file.type)
      }
    }
    document.addEventListener("trix-attachment-add", this._blockActionTextUpload, true)


    this._onTrixAttachmentAdd = async (event) => {
      const attachment = event.attachment
      const file = attachment?.file
      if (!file) return

      // Stop ActionText default upload
      event.preventDefault()
      event.stopImmediatePropagation()

      // Progress feedback
      attachment.setUploadProgress(0)

      // Resolve direct upload URL (from your hidden file input with direct_upload: true)
      const uploader = this.form?.querySelector('[data-paste-image-target="uploader"]')
      let uploadUrl = uploader?.dataset?.directUploadUrl || "/rails/active_storage/direct_uploads"

      try {
        const blob = await this.directUpload(file, uploadUrl)

        // Add hidden input so Rails attaches it on submit
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = file.type?.startsWith("image/") ? "squak[images][]" : "squak[files][]"
        input.value = blob.signed_id
        ;(this.signedIdsContainer || this.form).appendChild(input)

        // Set an in-editor preview so users see something
        if (file.type?.startsWith("image/")) {
          // Let Trix render an <img> preview; URL is not persisted server-side
          attachment.setAttributes({ url: URL.createObjectURL(file), href: "#" })
        } else {
          // Render a simple file badge
          const label = file.name || "file"
          attachment.setAttributes({
            content: `<figure class="attachment attachment--file"><span>${label}</span></figure>`
          })
        }

        attachment.setUploadProgress(100)
      } catch (e) {
        console.error("[squakeditor] Direct upload failed:", e)
        attachment.remove()
      }
    }

    this.element.addEventListener("trix-attachment-add", this._onTrixAttachmentAdd, true)



    // Optional: File validation
    this.element.addEventListener("trix-file-accept", this.onFileAccept)
  }

  disconnect() {
    document.removeEventListener("trix-toolbar-setup", this.onToolbarSetup)
    document.removeEventListener("trix-initialize", this.onTrixInitialize)
    this.element.removeEventListener("trix-change", this.onTrixChange)

    if (this._onTrixAttachmentAdd) {
      this.element.removeEventListener("trix-attachment-add", this._onTrixAttachmentAdd)
    }
    this.element.removeEventListener("trix-file-accept", this.onFileAccept)
  }

  beforeSubmit() {
    const hidden = document.querySelector("#squak-body")
    if (!this.hasEditorTarget || !hidden) return

    const clean = this.stripDataUris(this.editorTarget.innerHTML).trim()
    const hasAnyAttachment =
        this.hasSignedIdsTarget &&
        this.signedIdsTarget.querySelector('input[name="squak[images][]"], input[name="squak[files][]"]')

    hidden.value = (clean.length === 0 && hasAnyAttachment) ? "Attachment(s) below" : clean
  }

  directUpload(file, uploadUrl) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, uploadUrl)
      upload.create((error, blob) => (error ? reject(error) : resolve(blob)))
    })
  }

  // ---- URL detection/linkification using Trix editor API ----

  // Find most recent URL token that ends at or before caret
  findLatestUrlEndingAtOrBefore(text, caret) {
    if (!text) return null
    const lookBack = 2048
    const start = Math.max(0, caret - lookBack)
    const slice = text.slice(start, caret)

    const re = /\bhttps?:\/\/[^\s<>"')]+/gi
    let match, last = null
    while ((match = re.exec(slice)) !== null) {
      const raw = match[0]
      const url = this.normalizeUrlText(raw)
      if (!url) continue
      const absStart = start + match.index
      const absEnd = absStart + raw.length
      last = { url, start: absStart, end: absEnd }
    }
    return last
  }

  // Replace [start, end) with a link whose text is title and href is url
  replaceRangeWithLink(editor, start, end, url, title) {
    if (!editor || start == null || end == null || end <= start) return
    const docLength = editor.getDocument().toString().length
    const s = Math.max(0, Math.min(start, docLength))
    const e = Math.max(s, Math.min(end, docLength))

    editor.recordUndoEntry("Link URL")
    editor.setSelectedRange([s, e])
    editor.activateAttribute("href", url)
    editor.insertString(title || url)
    editor.deactivateAttribute("href")
  }

  // Replace the text content of the first link matching href, preserving its href
  replaceLinkTextByHref(editor, href, newText) {
    if (!href || !newText) return
    // Trix mirrors HTML into the associated input element; read and find the link
    const container = document.createElement("div")
    container.innerHTML = this.element.value || ""

    const link = container.querySelector(`a[href="${this.cssEscapeAttr(href)}"]`)
    if (!link) return

    // Compute the character offsets of that link within the plain text of the doc
    const preText = container.innerText
    const fullText = preText.toString()
    const linkText = link.textContent || ""
    const linkIndex = fullText.indexOf(linkText)
    if (linkIndex === -1) return

    const start = linkIndex
    const end = start + linkText.length

    // Re-apply within the editor
    this.replaceRangeWithLink(editor, start, end, href, newText)
  }

  rangeIsLinked(editor, start, end, url) {
    try {
      const container = document.createElement("div")
      container.innerHTML = this.element.value || ""
      return !!container.querySelector(`a[href="${this.cssEscapeAttr(url)}"]`)
    } catch {
      return false
    }
  }

// ---- Optional title fetcher ----
  async fetchTitle(url) {
    const resp = await fetch(`/link_preview?url=${encodeURIComponent(url)}`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    })
    if (!resp.ok) return null
    const data = await resp.json()
    return (data && data.title) ? String(data.title) : null
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

  // utils
  debounce(fn, delay) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn.apply(this, args), delay)
    }
  }

  cssEscapeAttr(s) {
    // Minimal escape for attribute selector usage in querySelector
    return String(s || "").replace(/["\\]/g,
        (c) => ({ '"': '\\"', "\\": "\\\\" }[c]))
  }


// 2) Normalize URLs: trim whitespace and trailing punctuation that
// commonly attaches in typing (.,),],},!,"', etc.)
  normalizeUrlText(raw) {
    if (!raw) return ""
    let url = raw.trim()
    // Strip trailing punctuation commonly typed after URLs
    url = url.replace(/[)\]\}.,!?'"“”’]+$/, "")
    // If the original ended with a closing paren and appears balanced, keep one
    if (/\)$/.test(raw)) {
      const opens = (raw.match(/\(/g) || []).length
      const closes = (raw.match(/\)/g) || []).length
      if (closes > opens) url += ")"
    }
    return url
  }

  // Called after Turbo finishes the request
  resetEditor(event) {
    // Only clear on success
    if (!event?.detail?.success) return

    // Find the editor associated with this form
    const form = event.target
    const trixEl = form.querySelector('trix-editor[input="squak-body"]')
    const hiddenInput = form.querySelector('#squak-body')

    if (trixEl?.editor) {
      trixEl.editor.loadHTML("") // clears the editor content
    }
    if (hiddenInput) {
      hiddenInput.value = "" // keep hidden input in sync
    }

    // Optional: clear any client-side URL previews tracked by this controller
    this._seenLinks = new Set()
    const previews = form.querySelector('[data-paste-image-target="previews"], [data-squakeditor-target="previews"]')
    if (previews) previews.innerHTML = ""
  }

}
