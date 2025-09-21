import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import "axios"

export default class extends Controller {
  connect() {
    console.log("AttachmentsController connected")
    this.element.addEventListener("trix-file-accept", event => {
      const { file } = event
      if (file.size > 500 * 1024 * 1024) {
        event.preventDefault()
        alert("File too large!")
      }
    })

    this.element.addEventListener("trix-attachment-add", event => {
      const { attachment } = event
      if (attachment.file) {
        console.log("trix-attachment-add triggered for file:", attachment.file.name)
        this.createDirectUpload(attachment)
      }
    })
  }

  async createDirectUpload(attachment) {
    const file = attachment.file
    console.log("Starting direct upload for:", file.name)
    const upload = new DirectUpload(file, this.uploadURL, {
      directUploadWillStoreFileWithXHR: xhr => {
        xhr.upload.addEventListener("progress", event => {
          const progress = (event.loaded / event.total) * 100
          attachment.setUploadProgress(progress)
        })
      }
    })

    try {
      const blob = await new Promise((resolve, reject) => {
        upload.create((error, blob) => {
          if (error) {
            console.error("Direct upload failed:", error)
            reject(error)
          } else {
            console.log("Direct upload succeeded, blob:", {
              id: blob.id,
              filename: blob.filename,
              content_type: blob.content_type,
              signed_id: blob.signed_id
            })
            resolve(blob)
          }
        })
      })
      if (file.type === "application/pdf") {
        await this.analyzeBlob(blob.signed_id)
        await this.fetchPreviewUrl(blob.signed_id, attachment)
      } else {
        console.log("Setting attributes for non-PDF:", blob.filename)
        attachment.setAttributes({
          url: blob.service_url,
          href: blob.service_url,
          sgid: blob.signed_id,
          filename: blob.filename,
          contentType: blob.content_type,
          previewable: blob.representable
        })
      }
    } catch (error) {
      console.error("Upload error:", error)
      console.log("Falling back to file attributes for:", file.name)
      attachment.setAttributes({
        url: file.service_url || file.url || file.name,
        href: file.service_url || file.url || file.name,
        sgid: "",
        filename: file.name,
        contentType: file.type,
        previewable: false
      })
      alert("Upload failed: " + error.message)
    }
  }

  async analyzeBlob(sgid, attempt = 0, maxAttempts = 5) {
    console.log("Analyzing blob for SGID:", sgid, "Attempt:", attempt + 1)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken) {
      console.error("CSRF token not found")
      return
    }
    try {
      const response = await window.axios.post(`/rails/active_storage/blobs/${sgid}/analyze`, {}, {
        headers: {
          "X-CSRF-Token": csrfToken
        }
      })
      console.log("Blob analysis response:", response.data)
    } catch (error) {
      console.error("Error analyzing blob:", {
        message: error.message,
        status: error.response?.status,
        data: error.response?.data,
        attempt: attempt + 1
      })
      if (attempt < maxAttempts && error.response?.status === 422) {
        console.log("Retrying blob analysis after 1s...")
        await new Promise(resolve => setTimeout(resolve, 1000))
        return this.analyzeBlob(sgid, attempt + 1, maxAttempts)
      }
      console.log("Analysis failed, proceeding to preview...")
    }
  }

  async fetchPreviewUrl(sgid, attachment, attempt = 0, maxAttempts = 10) {
    console.log("Fetching preview URL for SGID:", sgid, "Attempt:", attempt + 1)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken) {
      console.error("CSRF token not found")
      return
    }
    try {
      const response = await window.axios.get(`/rails/active_storage/blobs/${sgid}/preview`, {
        headers: {
          "X-CSRF-Token": csrfToken
        }
      })
      console.log("Preview URL response:", response.data)
      attachment.setAttributes({
        url: response.data.preview_url,
        href: response.data.url, // PDF download link
        sgid: response.data.sgid,
        filename: response.data.filename,
        contentType: "image/png",
        previewable: true
      })
      console.log("Trix attachment attributes set:", {
        url: response.data.preview_url,
        href: response.data.url,
        sgid: response.data.sgid,
        contentType: "image/png",
        previewable: true
      })
    } catch (error) {
      console.error("Error fetching preview URL:", {
        message: error.message,
        status: error.response?.status,
        data: error.response?.data,
        attempt: attempt + 1
      })
      if (attempt < maxAttempts && error.response?.status === 422) {
        console.log("Retrying preview fetch after 1s...")
        await new Promise(resolve => setTimeout(resolve, 1000))
        return this.fetchPreviewUrl(sgid, attachment, attempt + 1, maxAttempts)
      }
      console.log("Falling back to file attributes for:", attachment.file.name)
      attachment.setAttributes({
        url: attachment.file.service_url || attachment.file.url || attachment.file.name,
        href: attachment.file.service_url || attachment.file.url || attachment.file.name,
        sgid: sgid,
        filename: attachment.file.name,
        contentType: attachment.file.type,
        previewable: false
      })
      alert("Failed to load preview: " + (error.response?.data?.error || error.message))
    }
  }

  get uploadURL() {
    return this.data.get("direct-upload-url") || "/rails/active_storage/direct_uploads"
  }
}
