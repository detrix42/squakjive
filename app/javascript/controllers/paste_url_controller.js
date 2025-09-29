import {Controller} from "@hotwired/stimulus"
import "trix"
import {getClipboardImageItems, getPastedText, isUrl} from "trix_paste_utils"

export default class extends Controller {
  connect() {
    console.log("Paste controller connected")
    // Switch back to trix-paste for reliable pasted text access
    this.element.addEventListener("trix-paste", this.handlePaste.bind(this))
  }

  handlePaste = (event) => {
    if (event.__handled) return

    // Defer to image controller if images exist
    if (getClipboardImageItems(event).length > 0) return

    const text = getPastedText(event).trim()
    if (!isUrl(text)) return

    event.preventDefault()
    event.__handled = true
    event.stopImmediatePropagation()

    const normalized = this.normalizeUrl(text)
    this.insertBasicLink(text, normalized)
    this.fetchAndReplace(text, normalized) // your async enhancement

  }


  insertTextAtCursor(text) {
    this.editor.insertString(text)
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
      editor.setSelectedRange([start, originalEnd])
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
