import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import "axios"

export default class extends Controller {
  connect() {
    console.log("AttachmentsController connected")
    // this.element.addEventListener("trix-file-accept", event => {
    //   const { file } = event
    //   if (file.size > 500 * 1024 * 1024) {
    //     event.preventDefault()
    //     alert("File too large!")
    //   }
    // })

    this.element.removeEventListener("trix-file-accept", this.onFileAccept)
    this.element.removeEventListener("trix-attachment-add", this.onAttachmentAdd)

    this.element.addEventListener("trix-file-accept", this.onFileAccept)
    this.element.addEventListener("trix-attachment-add", this.onAttachmentAdd)

  }

  disconnect() {
    // Remove listeners to prevent stacking on Turbo reconnects
    this.element.removeEventListener("trix-file-accept", this.onFileAccept)
    this.element.removeEventListener("trix-attachment-add", this.onAttachmentAdd)
  }

// Bind handlers so we can remove them in disconnect()
  onFileAccept = event => {
    const { file } = event
    if (file.size > 500 * 1024 * 1024) {
      event.preventDefault()
      alert("File too large!")
    }
  }

  onAttachmentAdd = event => {
    // Prevent Trix's default direct upload to avoid duplicate uploads
    event.preventDefault()
    const { attachment } = event
    if (attachment.file) {
      console.log("trix-attachment-add triggered for file:", attachment.file.name)
      this.createDirectUpload(attachment)
    }
  }




  async createDirectUpload(attachment) {
    const file = attachment.file
    console.log("Starting direct upload for:", file.name)

    let lastProgress = 0
    let lastPaint = 0
    const minDelta = 2           // only update if progress moves by 2% or more
    const minInterval = 100      // ms between UI updates

    // requestAnimationFrame batching
    let rafId = null
    let queuedPct = null
    const flushProgress = () => {
      if (queuedPct == null) return
      attachment.setUploadProgress(queuedPct)
      queuedPct = null
      rafId = null
    }
    const setProgress = (pct) => {
      // batch to next frame
      queuedPct = pct
      if (rafId == null) {
        rafId = requestAnimationFrame(flushProgress)
      }
    }

    // Initialize to 0 once
    setProgress(0)


    const upload = new DirectUpload(file, this.uploadURL, {
      // Add CSRF for create-blob POST (helps avoid occasional 422s)
      directUploadWillCreateBlobWithXHR: xhr => {
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
        console.log("CSRF token:", csrfToken)
        if (csrfToken) xhr.setRequestHeader("X-CSRF-Token", csrfToken)
        // Help Rails treat this as an XHR and pass CSRF heuristics
        xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest")

      },
      // Track upload progress for the PUT to storage
      directUploadWillStoreFileWithXHR: xhr => {
        xhr.upload.addEventListener("progress", event => {
          if (!event.lengthComputable || !event.total) return

          const raw = (event.loaded / event.total) * 100
          // Clamp to [1, 99] to avoid bouncing 100 before we finalize
          let pct = Math.round(raw)
          pct = Math.max(0, Math.min(99, pct))
          if (pct < lastProgress) pct = lastProgress

          const now = performance.now()

          if (
              lastProgress < 0 ||
              (pct - lastProgress) >= minDelta ||
              (now - lastPaint) >= minInterval
          ) {
            lastProgress = pct
            lastPaint = now
            // attachment.setUploadProgress(pct)
            setProgress(pct)
          }
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

      // Upload is complete: snap to 100% once, after success
      attachment.setUploadProgress(100)

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
      const msg =
          (error && (error.message ||
              error.response?.data?.error ||
              error.response?.statusText ||
              (typeof error === "string" ? error : null))) ||
          "Unknown error (see console for details)"
      alert("Upload failed: " + msg)

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
