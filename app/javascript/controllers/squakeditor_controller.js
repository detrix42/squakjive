import { Controller } from "@hotwired/stimulus"
import {turboSubmitSucceeded} from "trix_paste_utils"
export default class extends Controller {
  static targets = []

  static values = {
    circleId: Number
  }

  initialize() {
    // Register underline once
    if (window.Trix && !Trix.config.textAttributes.underline) {
      console.log('registering underline')
      Trix.config.textAttributes.underline = {
        tagName: "u",
        inheritable: true,
        parser: el => el.tagName === "U" || el.style?.textDecoration?.includes("underline")
      }
    }

    // Toolbar setup hooks
    this.onToolbarSetup = (event) => {
      const toolbar = event.detail?.toolbarElement || event.toolbarElement
      if (toolbar) this.insertUnderlineIntoToolbar(toolbar)
    }
    this.onTrixInitialize = (event) => {
      const toolbar = event.target?.toolbarElement
      if (toolbar) this.insertUnderlineIntoToolbar(toolbar)
    }

    // Bind the submit-end handler so `this` stays the controller instance
    this._onTurboSubmitEnd = this.onTurboSubmitEnd.bind(this)
  }

  connect() {
    console.log("Squakeditor controller connected")
    // Only attach harmless toolbar hooks
    document.addEventListener("trix-toolbar-setup", this.onToolbarSetup)
    document.addEventListener("trix-initialize", this.onTrixInitialize)

    // Immediate pass for already-present toolbars
    document.querySelectorAll("trix-toolbar").forEach((tb) => {
      this.insertUnderlineIntoToolbar(tb)
    })

    // Attach to a form (controller can be on the form or any descendant)
    this.form = this.element.closest("form") || (this.element.tagName === "FORM" ? this.element : null)
    // Listen for Turbo submission completion for this form
    if (this.form) {
      this.form.addEventListener("turbo:submit-end", this._onTurboSubmitEnd)
    }
  }

  disconnect() {
    document.removeEventListener("trix-toolbar-setup", this.onToolbarSetup)
    document.removeEventListener("trix-initialize", this.onTrixInitialize)
    if (this.form && this._onTurboSubmitEnd) {
      this.form.removeEventListener("turbo:submit-end", this._onTurboSubmitEnd)
    }
  }

  // Insert a simple underline button next to italic, if desired
  insertUnderlineIntoToolbar(toolbarElement) {
    if (!toolbarElement) return
    const group = toolbarElement.querySelector(".trix-button-group--text-tools")
    if (!group || group.querySelector(".trix-button--icon-underline")) return

    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "trix-button trix-button--icon trix-button--icon-underline"
    btn.setAttribute("data-trix-attribute", "underline")
    btn.setAttribute("data-trix-key", "u")
    btn.setAttribute("aria-label", "Underline")
    btn.setAttribute("title", "Underline")
    btn.setAttribute("tabindex", "-1")

    const italicBtn = group.querySelector('[data-trix-attribute="italic"]')
    if (italicBtn) {
      const afterItalic = italicBtn.nextSibling
      if (afterItalic) {
        group.insertBefore(btn, afterItalic)
      } else {
        group.appendChild(btn)
      }
    } else {
      group.appendChild(btn)
    }
  }


  onTurboSubmitEnd(event) {
    if (!(event?.target instanceof HTMLFormElement)) return
    if (this.form && event.target !== this.form) return
    if (!turboSubmitSucceeded(event)) return

    this.clearEditor()
  }

  clearEditor() {
    const trixEl = this.form?.querySelector("trix-editor")
    if (!trixEl?.editor) return

    const editor = trixEl.editor
    editor.recordUndoEntry("Clear")
    editor.loadHTML("")

    const inputId = trixEl.getAttribute("input")
    if (inputId) {
      const hidden = document.getElementById(inputId)
      if (hidden) {
        hidden.value = ""
        hidden.dispatchEvent(new Event("input", {bubbles: true}))
      }
    }

    trixEl.focus()
  }


}
