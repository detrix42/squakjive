// app/javascript/controllers/paste_image_controller.js
import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["uploader", "signedIds", "previews", "editor"]

  connect() {
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
    if (event.detail?.success) {
      if (this.hasPreviewsTarget) this.previewsTarget.innerHTML = ""
      if (this.hasSignedIdsTarget) this.signedIdsTarget.innerHTML = ""
      if (this.hasUploaderTarget) this.uploaderTarget.value = ""
    }
  }


  beforeSubmit() {
    const hidden = document.querySelector("#squak-body")
    if (!this.hasEditorTarget || !hidden) return

    const clean = this.stripDataUris(this.editorTarget.innerHTML).trim()
    const hasImages = this.hasSignedIdsTarget && this.signedIdsTarget.querySelector('input[name="squak[images][]"]')

    // Ensure the backend never sees base64 and presence validation can pass when images exist
    hidden.value = (clean.length === 0 && hasImages) ? "Image attached below" : clean

  }



  onPaste(event) {
    if (!event.clipboardData) return

    const items = Array.from(event.clipboardData.items || [])
    const imageItems = items.filter(i => i.kind === "file" && i.type.startsWith("image/"))

    if (imageItems.length > 0) {
      // Prevent the image being inserted as a base64 blob into the editor
      event.preventDefault()

      imageItems.forEach(item => {
        const file = item.getAsFile()
        if (!file) return
        this.uploadFile(file)
      })

      // Insert any text/plain that came with the paste, otherwise a placeholder
      const plain = (event.clipboardData.getData("text/plain") || "").trim()
      if (plain) {
        this.insertTextAtCursor(plain + " ")
      } else {
        this.insertTextAtCursor("See attached image(s)")
      }
      // Trigger input pipeline (e.g., syncing to hidden textarea)
      this.onEditorInput()
      return
    }

    // If someone copies HTML that contains data URIs, block them and optionally paste plain text
    const html = event.clipboardData.getData("text/html")
    if (html && this.containsDataUri(html)) {
      event.preventDefault()
      const text = event.clipboardData.getData("text/plain") || ""
      this.insertTextAtCursor(text)
    }
    // Otherwise let the paste fall through (normal text paste)

  }


  uploadFile(file) {
    const uploadUrl = this.uploaderTarget.dataset.directUploadUrl
    if (!uploadUrl) {
      console.error("Active Storage direct upload URL missing. Ensure ActiveStorage.start() and data-direct-upload='true' on the file input.")
      return
    }

    const upload = new DirectUpload(file, uploadUrl)

    // Optimistic preview
    this.addPreview(URL.createObjectURL(file))

    upload.create((error, blob) => {
      if (error) {
        console.error("Direct upload failed:", error)
        this.addErrorPreview()
      } else {
        // Append hidden input with signed_id so Rails attaches on submit
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "squak[images][]"
        input.value = blob.signed_id
        this.signedIdsTarget.appendChild(input)
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
