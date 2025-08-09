import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import TurndownService from "turndown"

export default class extends Controller {
  static targets = ["squakEditor", "markdown", "circleId", "html"]

  static values = {
    circleId: Number
  }

  connect() {
    console.log("Squakeditor controller connected")

    // Prefer paragraphs over divs when pressing Enter
    try {
      document.execCommand("defaultParagraphSeparator", false, "p")
    } catch (_) {}

    // Initial sync if editor has preloaded content
    this.sync()

    // Keep track of selection so toolbar buttons work
    this.savedRange = null
    this.squakEditorTarget.addEventListener("keyup", this.saveSelection)
    this.squakEditorTarget.addEventListener("mouseup", this.saveSelection)
    this.squakEditorTarget.addEventListener("mouseleave", this.saveSelection)
    this.squakEditorTarget.addEventListener("blur", this.saveSelection)

    // Keep hidden input in sync
    this.squakEditorTarget.addEventListener("input", this.sync)
    this.squakEditorTarget.addEventListener("paste", () => requestAnimationFrame(this.sync))

    // Ensure final value is synced on submit
    const formEl = this.element.closest("form")
    if (formEl) formEl.addEventListener("submit", this._boundSync)

  }

  disconnect() {
    if (this.hasSquakEditorTarget) {
      this.squakEditorTarget.removeEventListener("keyup", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("mouseup", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("mouseleave", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("blur", this._boundSaveSelection)
      this.squakEditorTarget.removeEventListener("input", this._boundSync)

    }

    const formEl = this.element.closest("form")
    if (formEl) formEl.removeEventListener("submit", this._boundSync)

  }

  format(event) {
    const cmd = event.currentTarget?.dataset?.format
    if (!cmd) return

    this.restoreSelection()
    this.squakEditorTarget.focus()
    document.execCommand(cmd, false, null)
    this.sync()

  }

  // Save current selection range
  saveSelection = () => {
    const sel = window.getSelection()
    if (sel && sel.rangeCount > 0) {
      this.savedRange = sel.getRangeAt(0)
    }
  }


  // Restore saved selection range
  restoreSelection = () => {
    if (!this.savedRange) return
    const sel = window.getSelection()
    if (!sel) return
    sel.removeAllRanges()
    sel.addRange(this.savedRange)
  }


  // Mirror editor HTML into hidden input for submission
  sync = () => {
    if (this.hasHtmlTarget && this.hasSquakEditorTarget) {
      this.htmlTarget.value = this.squakEditorTarget.innerHTML
    }
  }



}
