// app/javascript/controllers/paste_image_controller.js
import {Controller} from "@hotwired/stimulus"
import {turboSubmitSucceeded} from "trix_paste_utils"
import { DirectUpload } from "@rails/activestorage"
import { getClipboardImageItems, getPastedText } from "trix_paste_utils"

export default class extends Controller {

  static targets = ["uploader", "signedIds", "previews", "editor"]

  connect() {
    console.log("Paste image controller connected")
    // Ensure we bind to the real trix-editor node
    this.trixEl = this.element.tagName === "TRIX-EDITOR"
        ? this.element
        : this.element.querySelector("trix-editor")

    if (!this.trixEl) {
      console.warn("[paste_image] No <trix-editor> found to bind paste handlers")
      return
    }

    this.onPaste = this.onPaste.bind(this)
    this.onPasteCapture = (e) => {
      // Only handle paste events originating inside our trix editor
      const targetEditor = e.target?.closest?.("trix-editor")
      if (!targetEditor || targetEditor !== this.trixEl) return
      // Run our handler in capture phase before Trix
      this.onPaste(e)
    }

    window.addEventListener("paste", this.onPasteCapture, true)
    // Bind both Trix’s synthetic and native paste events
    this.trixEl.addEventListener("trix-paste", this.onPaste)
    this.trixEl.addEventListener("paste", this.onPaste)

    // console.debug("[paste_image] connected and listening for paste on", this.trixEl)



    // Ensure we can clean up before submit
    this.form = this.element.closest("form")

    // Clear previews/inputs after a successful submit
    if (this.form) {
      this._onTurboSubmitStart = this.onTurboSubmitStart.bind(this)
      this._onTurboSubmitEnd = this.onTurboSubmitEnd.bind(this)
      this.form.addEventListener("turbo:submit-start", this._onTurboSubmitStart)
      this.form.addEventListener("turbo:submit-end", this._onTurboSubmitEnd)
    }
  }

  disconnect() {
    if (this.trixEl && this.onPaste) {
      this.trixEl.removeEventListener("trix-paste", this.onPaste)
    }
    if (this.onPasteCapture) {
      window.removeEventListener("paste", this.onPasteCapture, true)
    }

    if (this.form) {
      if (this._onTurboSubmitStart) this.form.removeEventListener("turbo:submit-start", this._onTurboSubmitStart)
      if (this._onTurboSubmitEnd) this.form.removeEventListener("turbo:submit-end", this._onTurboSubmitEnd)
    }

  }



  // Keep previews visible during the request so the user sees what's being sent.
  onTurboSubmitStart() {
    // no-op on purpose
  }

  // After a successful submit, clear previews and hidden signed_id inputs
  onTurboSubmitEnd(event) {
    if (!turboSubmitSucceeded(event)) return

    if (this.hasPreviewsTarget) this.previewsTarget.innerHTML = ""
    if (this.hasSignedIdsTarget) this.signedIdsTarget.innerHTML = ""
    if (this.hasUploaderTarget) this.uploaderTarget.value = ""
  }


  beforeSubmit() {
    const hidden = document.querySelector("#squak-body")
    if (!this.hasEditorTarget || !hidden) return

    const clean = this.stripDataUris(this.editorTarget.innerHTML).trim()
    const hasImages = this.hasSignedIdsTarget && this.signedIdsTarget.querySelector('input[name="squak[images][]"]')

    // Ensure the backend never sees base64 and presence validation can pass when images exist
    hidden.value = (clean.length === 0 && hasImages) ? "Image attached below" : clean

  }

  get editor() {
    return this.trixEl?.editor || this.element.editor
  }


  onPaste(event) {
    console.debug("[paste_image] onPaste fired:", event.type)
    if (event.__handled) return
    if (!event.clipboardData) return

    // Clipboard presence can be missing on the Trix synthetic event; prefer native
    const cd = event.clipboardData || event.paste
    if (!cd) return


    // Detect pasted images
    const imageItems = getClipboardImageItems(event)
    if (imageItems.length === 0) {
      // Optional: sanitize pasted HTML with data URIs when no images present
      const html = event.clipboardData?.getData("text/html")
      if (html && this.containsDataUri(html)) {
        event.preventDefault()
        event.__handled = true
        event.stopImmediatePropagation()
        const text = event.clipboardData.getData("text/plain") || ""
        this.insertTextAtCursor(text)
        return
      }

      const plain = (getPastedText(event) || "").trim()
      if (!plain) {
        event.preventDefault()
        event.__handled = true
        if (typeof event.stopImmediatePropagation === "function") {
          event.stopImmediatePropagation()
        }
        this.insertTextAtCursor("There is no conent")
        return
      }

      // Let paste-url handle plain URL pastes.
      if (event.__handled) return

      // Otherwise, let normal text paste happen
      return
    }


    // Stop default before Trix inserts base64
    event.preventDefault()
    event.__handled = true
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation()
    }

    // Suspend any other interceptors while we insert our own attachment
    window.__suspendAttachmentInterception = true

    imageItems.forEach(item => {
      const file = item.getAsFile()
      if (!file) return

      // Insert a real Trix attachment with a temporary URL so it renders inline
      const tempUrl = URL.createObjectURL(file)
      const attachment = new Trix.Attachment({
        contentType: file.type || "image/*",
        filename: file.name,
        url: tempUrl
      })

      const editor = this.editor
      editor.insertAttachment(attachment)

      // Direct upload, then swap URLs on the existing attachment
      this.directUploadFile(file)
          .then(async (signedId) => {
            try {
              attachment.setAttributes({
                sgid: signedId,
                filename: file.name,
                contentType: file.type || "image/*"
              })

              const res = await fetch("/api/v1/uploads", {
                method: "POST",
                headers: { "Content-Type": "application/json", "Accept": "application/json" },
                body: JSON.stringify({ signed_id: signedId })
              })
              if (!res.ok) throw new Error("Failed to resolve blob URLs")
              const data = await res.json()

              attachment.setAttributes({
                url: data.preview_url,
                href: data.download_url
              })
            } catch (e) {
              console.error("Failed to finalize uploaded image:", e)
              attachment.setAttributes({ caption: "Image upload failed" })
            } finally {
              URL.revokeObjectURL(tempUrl)
            }
          })
          .catch(err => {
            console.error("Direct upload failed:", err)
            attachment.setAttributes({ caption: "Image upload failed" })
            URL.revokeObjectURL(tempUrl)
          })

      // this.uploadFile(file)
    })

    // If clipboard also contains plain text, insert it; otherwise a placeholder
    const text = getPastedText(event).trim()
    if (text) {
      this.insertTextAtCursor(text + " ")
    }

    // Re-enable on next tick
    setTimeout(() => {
      window.__suspendAttachmentInterception = false
    }, 0)


    // Done handling images; do not fall through to other logic
    return
  }

  // Return a Promise that resolves with blob.signed_id
  directUploadFile(file) {
    const uploadUrl = this.directUploadUrl
    if (!uploadUrl) {
      return Promise.reject(new Error("Missing direct upload URL"))
    }
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, uploadUrl)
      upload.create((error, blob) => {
        if (error) {
          reject(error)
        } else {
          // If you still need hidden inputs for non-ActionText attachments, you can add them here.
          resolve(blob.signed_id)
        }
      })
    })
  }

  get directUploadUrl() {
    // Prefer the form that contains the actual <trix-editor>
    const form =
        this.trixEl?.closest?.("form") ||
        this.element?.closest?.("form") ||
        document.querySelector("form[data-direct-upload-url]")

    const url = form?.dataset?.directUploadUrl
    if (!url) {
      console.error(
          "[paste_image] Missing data-direct-upload-url. Ensure your form has:",
          'data-direct-upload-url="/rails/active_storage/direct_uploads"'
      )
    }
    return url || "/rails/active_storage/direct_uploads"
  }


  uploadFile(file) {
    const uploadUrl = this.directUploadUrl
    if (!uploadUrl) {
      console.error("Active Storage direct upload URL missing. Ensure ActiveStorage.start() and data-direct-upload='true' on the file input.")
      return
    }

    const upload = new DirectUpload(file, uploadUrl)

    // Optimistic preview
    this.addPreview(URL.createObjectURL(file))

    console.debug("[paste_image] Direct uploading:", file.name, file.type)
    upload.create((error, blob) => {
      if (error) {
        console.error("Direct upload failed:", error)
        this.addErrorPreview()
      } else {
        // Append hidden input with signed_id so Rails attaches on submit
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = file.type && file.type.startsWith("image/")
            ? "squak[images][]"
            : "squak[files][]"
        input.value = blob.signed_id
        this.signedIdsTarget.appendChild(input)
        console.debug("[paste_image] Added signed_id:", blob.signed_id, "->", input.name)
      }
    })
  }

  addPreview(objectUrl) {
    if (!this.hasPreviewsTarget) return
    const img = document.createElement("img")
    img.src = objectUrl
    img.className = "img-thumbnail"
    img.style.maxWidth = "140px"
    img.style.maxHeight = "140px"
    img.onload = () => URL.revokeObjectURL(objectUrl)
    this.previewsTarget.appendChild(img)
  }

  addErrorPreview() {
    if (!this.hasPreviewsTarget) return
    const el = document.createElement("div")
    el.textContent = "Image upload failed"
    el.className = "text-danger small me-2"
    this.previewsTarget.appendChild(el)
  }

  onEditorInput() {
    if (!this.hasEditorTarget) return
    const before = this.editorTarget.innerHTML
    const after = this.stripDataUris(before)
    if (before !== after) {
      this.editorTarget.innerHTML = after
      this.placeCaretAtEnd(this.editorTarget)
    }

  }

  // Utilities

  containsDataUri(html) {
    // Looks for data: URIs (e.g., <img src="data:image/png;base64,...">)
    return /(?:src|href)\s*=\s*["']\s*data:/i.test(html)
  }

  stripDataUris(html) {
    // Remove any <img src="data:..."> entirely
    let out = html.replace(/<img\b[^>]*\bsrc\s*=\s*["']\s*data:[^"']*["'][^>]*>/gi, "")
    // Also remove any remaining data: URIs in attributes to be extra safe
    out = out.replace(/(["'])\s*data:[^"']*\1/gi, '""')
    return out
  }

  insertTextAtCursor(text) {
    // Prefer execCommand for contenteditable cross-browser plain-text paste fallback
    if (document.queryCommandSupported && document.queryCommandSupported("insertText")) {
      document.execCommand("insertText", false, text)
      return
    }
    // Fallback: insert a text node
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) return
    const range = sel.getRangeAt(0)
    range.deleteContents()
    range.insertNode(document.createTextNode(text))
    // Move caret to end of inserted text
    range.collapse(false)
    sel.removeAllRanges()
    sel.addRange(range)
  }

  placeCaretAtEnd(el) {
    el.focus()
    if (typeof window.getSelection !== "undefined"
        && typeof document.createRange !== "undefined") {
      const range = document.createRange()
      range.selectNodeContents(el)
      range.collapse(false)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
  }


}
