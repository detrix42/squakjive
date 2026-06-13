import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import "axios"

export default class extends Controller {
  connect() {
    console.log("AttachmentsController connected")

    this.attachment_in_progress = false
    this.csrfTkn = document.querySelector('meta[name="csrf-token"]')?.content || ""


    // const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if(window.axios) {
      window.axios.defaults.headers.common['X-CSRF-Token'] = this.csrfTkn
      window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest'
      window.axios.defaults.headers.common['Accept'] = 'application/json'
      window.axios.defaults.headers.common['Content-Type'] = 'application/json'
    }

    this.element.removeEventListener("trix-file-accept", this.onFileAccept)
    this.element.removeEventListener("trix-attachment-add", this.onAttachmentAdd)
    this.element.removeEventListener("trix-attachment-remove", this.onAttachmentRemove)

    this.element.addEventListener("trix-file-accept", this.onFileAccept)
    this.element.addEventListener("trix-attachment-add", this.onAttachmentAdd, this.attachment_in_progress)
    this.element.addEventListener("trix-attachment-remove", this.onAttachmentRemove)
  }

  disconnect() {
    // Remove listeners to prevent stacking on Turbo reconnects
    this.element.removeEventListener("trix-file-accept", this.onFileAccept)
    this.element.removeEventListener("trix-attachment-add", this.onAttachmentAdd)
    this.element.removeEventListener("trix-attachment-remove", this.onAttachmentRemove)
  }

// Bind handlers so we can remove them in disconnect()
  onFileAccept = event => {
    console.log('onFileAccept')
    const { file } = event
    if (file.size > 500 * 1024 * 1024) {
      event.preventDefault()
      alert("File too large!")
    }
  }

  onAttachmentAdd = event => {
    console.log('onAttachmentAdd');
    event.preventDefault();
    event.stopPropagation();

    if (window.__suspendAttachmentInterception) return;

    const { attachment } = event;
    if (!attachment || !attachment.file) {
      console.log("No file or attachment, letting Trix handle normally");
      return;
    }

    if (!attachment || !attachment.file) return;

    if (attachment.__uploadProcessed) return;
    attachment.__uploadProcessed = true;

    attachment.setAttributes({ upload: null });

    console.log("trix-attachment-add triggered for file:", attachment.file.name);
    this.createDirectUpload(attachment);
  }

  onAttachmentRemove = event => {
    console.log("trix-attachment-remove triggered", event.attachment)
  }


  async createDirectUpload(attachment) {
    if (this.attachment_in_progress) {
      console.log("Upload in progress, skipping:", attachment.file.name)
      return
    }

    this.attachment_in_progress = true
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
        if (this.csrfTkn) xhr.setRequestHeader("X-CSRF-Token", this.csrfTkn)
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
      const serviceUrl = `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}?disposition=inline`;
      console.log("Service URL:", serviceUrl)

      // Define previewable MIME types (PDFs and videos need server-side previews)
      const previewableTypes = [
        "application/pdf",
        "video/mp4",
        "video/mpeg",
        "video/webm",
        "video/mov",
        "video/avi"
      ]

      // Define image types (use browser scaling, no server-side preview)
      const imageTypes = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/bmp",
        "image/webp",
        "image/tiff"
      ]

      if (previewableTypes.includes(blob.content_type)) {
        // PDFs and videos: analyze and fetch preview
        await this.analyzeBlob(blob.signed_id)
        await this.fetchPreviewUrl(blob.signed_id, attachment)
      }
      else if (imageTypes.includes(blob.content_type)) {
        // Images: use blob.service_url directly, let browser scale
        console.log("Setting attributes for image:", blob.filename)
        setTimeout(() => {
          attachment.setAttributes({
            url: serviceUrl,
            href: serviceUrl,
            sgid: blob.signed_id,
            filename: blob.filename,
            contentType: blob.content_type,
            previewable: true,
            caption: blob.filename || "",
          });
          console.log("Image attributes set:", attachment.getAttributes());
        }, 100);
      }
      else {
        // Non-previewable files
        console.log("Setting attributes for non-previewable file:", blob.filename)
        attachment.setAttributes({
          url: blob.service_url,
          href: blob.service_url,
          sgid: blob.signed_id,
          filename: blob.filename,
          contentType: blob.content_type,
          previewable: false,
          caption: blob.filename || "",
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
    finally {
      this.attachment_in_progress = false
      // Reset progress to 0
      attachment.__uploadProcessed = false; // Reset for future uploads
    }
  }

  async analyzeBlob(sgid, attempt = 0, maxAttempts = 5) {
    console.log("Analyzing blob for SGID:", sgid, "Attempt:", attempt + 1)

    try {
      const response = await window.axios.post(`/rails/active_storage/blobs/${sgid}/analyze`, {}, {
        headers: {
          "X-CSRF-Token": this.csrfTkn
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

  async fetchPreviewUrl(sgid, attachment, attempt = 0, maxAttempts = 5) {
    console.log("Fetching preview URL for SGID:", sgid, "Attempt:", attempt + 1)
    try {
      const response = await window.axios.get(`/rails/active_storage/blobs/${sgid}/preview`, {
        headers: { "X-CSRF-Token": this.csrfTkn }
      })
      console.log("Preview URL response:", response.data)
      attachment.setAttributes({
        url: response.data.preview_url,
        href: response.data.url,
        sgid: response.data.sgid,
        filename: response.data.filename,
        contentType: response.data.content_type || attachment.file.type,
        preview_url: response.data.preview_url,
        previewable: true
      })

      // Add a hidden input to the form with the preview_url
      const form = this.element.closest('form')
      if (form) {
        let hiddenInput = form.querySelector(`input[type="hidden"][name="squak[body_attributes][preview_urls][${sgid}]"]`)
        if (!hiddenInput) {
          hiddenInput = document.createElement('input')
          hiddenInput.type = 'hidden'
          hiddenInput.name = `squak[preview_urls][${sgid}]`
          form.appendChild(hiddenInput)
        }
        hiddenInput.value = response.data.preview_url
      }

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
        url: attachment.file.url || attachment.file.name,
        href: attachment.file.url || attachment.file.name,
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
