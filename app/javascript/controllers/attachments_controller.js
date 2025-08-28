import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener("trix-attachment-add", (event) => {
      const { attachment } = event;
      if (attachment.file) {
        this.uploadAttachment(attachment);
      }
    });

    // Optional: Prevent certain file types or sizes if needed
    this.element.addEventListener("trix-file-accept", (event) => {
      const { file } = event;
      if (file.size > 100 * 1024 * 1024) { // e.g., reject >100MB
        event.preventDefault();
        alert("File too large!");
      }
    });
  }

  uploadAttachment(attachment) {
    const file = attachment.file;
    const formData = new FormData();
    formData.append("Content-Type", file.type);
    formData.append("attachment[file]", file); // 'attachment[file]' matches backend params

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/attachments", true); // Your backend endpoint
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector('meta[name="csrf-token"]').content);

    xhr.upload.onprogress = (event) => {
      const progress = (event.loaded / event.total) * 100;
      attachment.setUploadProgress(progress);
    };

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        const data = JSON.parse(xhr.responseText);
        attachment.setAttributes({
          url: data.url,
          href: data.url, // For downloadable links on non-media files
          sgid: data.sgid // Optional for Action Text-like embedding
        });
      } else {
        attachment.remove();
        alert("Upload failed!");
      }
    };

    xhr.send(formData);
  }
}
