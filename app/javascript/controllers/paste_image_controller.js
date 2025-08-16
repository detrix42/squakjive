// app/javascript/controllers/paste_image_controller.js
import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["uploader", "signedIds", "previews", "editor"]

  connect() {
    // Ensure we can clean up before submit
    this.form = this.element.closest("form")
    if (this.form) {
      this._onSubmit = this.beforeSubmit.bind(this)
      this.form.addEventListener("submit", this._onSubmit)
    }
  }

  disconnect() {
    if (this.form && this._onSubmit) {
      this.form.removeEventListener("submit", this._onSubmit)
    }
  }


  onPaste(event) {
    if (!event.clipboardData) return

    const items = Array.from(event.clipboardData.items || [])
    const imageItems = items.filter(i => i.kind === "file" && i.type.startsWith("image/"))
    if (imageItems.length === 0) return

    // Prevent the image being inserted as a base64 blob into the editor
    event.preventDefault()

    imageItems.forEach(item => {
      const file = item.getAsFile()
      if (!file) return
      this.uploadFile(file)
    })
  }

  uploadFile(file) {
    const uploadUrl = this.uploaderTarget.dataset.directUploadUrl
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
    // Optional: if you need to mirror editor HTML/text into your hidden textarea here,
    // you can do it, for example:
    // const hidden = document.querySelector("#squak-body")
    // if (hidden && this.hasEditorTarget) hidden.value = this.editorTarget.innerHTML
  }
}
