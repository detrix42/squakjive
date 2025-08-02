import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import TurndownService from "turndown"

export default class extends Controller {
  static targets = ["squakEditor", "markdown", "circleId"]

  static values = {
    circleId: Number
  }

  connect() {
    console.log("Squakeditor controller connected")

    // if (this.hasMarkdownTarget && this.markdownTarget.value) {
    //   this.squakEditorTarget.innerHTML = marked.parse(this.markdownTarget.value)
    // }
    
    console.log('circle Id value:', this.circleIdValue)
    const e = document.querySelector('[name="squak[circle_id]"]')
    e.value = this.circleIdValue

    this.syncToMarkdown = this.debounce(this._syncToMarkdown.bind(this), 500)  // Debounce to 500ms for better perf
    this.squakEditorTarget.addEventListener('input', (e) => {
      // console.log('typing check')
      this.syncToMarkdown(e)
    })
  }

  disconnect() {
    this.squakEditorTarget.removeEventListener('input', this.syncToMarkdown)
  }

  format(event) {
    event.preventDefault()
    const format = event.currentTarget.dataset.format
    document.execCommand(format)
    this.syncToMarkdown()  // Sync after format
  }

  _syncToMarkdown() {
    if (!this.hasMarkdownTarget) {
      // console.log('Markdown target not found');
      return;
    }

    // console.log('syncing to Markdown');
    const html = this.squakEditorTarget.innerHTML;
    // console.log('HTML content:', html);

    const td = new TurndownService();
    td.keep(['u']);
    const md = td.turndown(html);
    // console.log('Converted markdown:', md);

    this.markdownTarget.value = md;
    // console.log('Textarea value after update:', this.markdownTarget.value);
  }

  debounce(func, delay) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => func(...args), delay)
    }
  }
}
