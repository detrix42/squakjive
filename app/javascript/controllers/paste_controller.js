import { Controller } from "@hotwired/stimulus"
import "trix"

export default class extends Controller {
  connect() {
    console.log("Paste controller connected")
    // Switch back to trix-paste for reliable pasted text access
    this.element.addEventListener("trix-paste", this.handlePaste.bind(this))
  }

  handlePaste(event) {
    const rawText = this.getPastedText(event)
    const pastedText = typeof raw === 'string' ? raw.trim() : ''

    // Log for debugging
    console.log('Pasted text (from trix-paste):', pastedText)
    console.log('Pasted text (JSON):', JSON.stringify(pastedText))
    console.log('Pasted text length:', pastedText.length)

    if (this.isUrl(pastedText)) {
      // Prevent default to stop plain insertion
      event.preventDefault()

      const normalizedUrl = this.normalizeUrl(pastedText)

      // Insert basic link first (synchronous)
      this.insertBasicLink(pastedText, normalizedUrl)

      // Then async enhance
      this.fetchAndReplace(pastedText, normalizedUrl)
    }
    // If not URL, default happens (but since we prevented only if URL, adjust if needed)
  }

  getPastedText(event) {
    try {
      if (event?.paste && typeof event.paste.getData === "function") {
        // Trix "trix-paste" API
        return event.paste.getData("text/plain") || event.paste.getData("text") || ""
      }
      if (event?.clipboardData && typeof event.clipboardData.getData === "function") {
        // Native ClipboardEvent fallback
        return event.clipboardData.getData("text/plain") || ""
      }
      // IE fallback
      if (window.clipboardData && typeof window.clipboardData.getData === "function") {
        return window.clipboardData.getData("Text") || ""
      }
    } catch (e) {
      console.warn("Failed to read pasted text:", e)
    }
    return ""
  }


  insertBasicLink(pastedText, normalizedUrl) {
    const editor = this.editor

    // Insert as plain text first
    editor.insertString(pastedText)

    // Then immediately link it
    const endPosition = editor.getPosition()
    const startPosition = endPosition - pastedText.length

    editor.setSelectedRange([startPosition, endPosition])
    editor.activateAttribute("href", normalizedUrl)
    editor.setSelectedRange([endPosition, endPosition])
  }

  async fetchAndReplace(pastedText, normalizedUrl) {
    const editor = this.editor
    const originalEnd = editor.getPosition() // Approx position after insert

    const start = originalEnd - pastedText.length
    const end = originalEnd

    try {
      const response = await fetch(`/api/v1/metadata?url=${encodeURIComponent(normalizedUrl)}`)
      const data = await response.json()
      console.log("Metadata fetch response:", data)

      if (data.error) {
        throw new Error("Metadata fetch failed")
      }

      const currentHref = editor.getDocument().getPieceAtPosition(start)?.getAttribute("href")
      if (currentHref !== normalizedUrl) {
        console.warn("Content changed - skipping replacement")
        return
      }

      let content
      if (data.type === "youtube") {
        content = `<a href="${data.url}" target="_blank"><img src="${data.thumbnail}" alt="${data.title || "YouTube Video"}" style="max-width: 100%;"></a>`
      } else {
        const linkText = (data.title && data.title !== "Untitled" && data.title.trim().length > 0) ? data.title : data.url
        content = `<a href="${data.url}" target="_blank">${linkText}</a>`
      }

      // Replace
      editor.setSelectedRange([start, end])
      editor.deleteInDirection("backward")
      const attachment = new Trix.Attachment({
        content: content,
        contentType: "text/html"
      })
      editor.insertAttachment(attachment)
    } catch (error) {
      console.error("Failed to enhance pasted URL:", error)
      // Leave basic link if fails
    }
  }

  isUrl(text) {
    const urlPattern = /^(https?:\/\/)?((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|((\d{1,3}\.){3}\d{1,3}))(:\d+)?(\/[-a-z\d%_.~+]*)*(\?[;&a-z\d%_.~+=-]*)?(#[-a-z\d_]*)?$/i;
    return urlPattern.test(text);
  }

  normalizeUrl(text) {
    if (text.match(/^https?:\/\//i)) {
      return text;
    } else {
      return `https://${text}`;
    }
  }

  get editor() {
    return this.element.editor
  }
}
