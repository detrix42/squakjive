import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "stage", "image"]

  static values = {
    minScale: { type: Number, default: 0.1 },
    maxScale: { type: Number, default: 12 },
    zoomFactor: { type: Number, default: 1.12 }
  }

  connect() {
    this.scale = 1
    this.translateX = 0
    this.translateY = 0
    this.isDragging = false
    this.activePointerId = null
    this.lastPointerX = 0
    this.lastPointerY = 0
    this.fitted = false

    if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) {
      this.fitToViewport()
    }
  }

  imageLoaded() {
    this.fitToViewport()
  }

  zoom(event) {
    event.preventDefault()

    const rect = this.viewportTarget.getBoundingClientRect()
    const pointerX = event.clientX - rect.left
    const pointerY = event.clientY - rect.top
    const direction = event.deltaY < 0 ? 1 : -1
    const factor = direction > 0 ? this.zoomFactorValue : 1 / this.zoomFactorValue

    this.zoomAt(pointerX, pointerY, factor)
  }

  zoomAt(pointerX, pointerY, factor) {
    const oldScale = this.scale
    const newScale = this.clampScale(oldScale * factor)
    if (newScale === oldScale) return

    const ratio = newScale / oldScale
    this.translateX = pointerX - ratio * (pointerX - this.translateX)
    this.translateY = pointerY - ratio * (pointerY - this.translateY)
    this.scale = newScale
    this.applyTransform()
  }

  startPan(event) {
    if (event.button !== 0 || !this.shouldPan(event)) return

    this.isDragging = true
    this.activePointerId = event.pointerId
    this.lastPointerX = event.clientX
    this.lastPointerY = event.clientY
    this.viewportTarget.setPointerCapture(event.pointerId)
    this.viewportTarget.classList.add("is-dragging")
  }

  pan(event) {
    if (!this.isDragging || event.pointerId !== this.activePointerId) return

    const dx = event.clientX - this.lastPointerX
    const dy = event.clientY - this.lastPointerY
    this.translateX += dx
    this.translateY += dy
    this.lastPointerX = event.clientX
    this.lastPointerY = event.clientY
    this.applyTransform()
  }

  endPan(event) {
    if (!this.isDragging || (this.activePointerId != null && event.pointerId !== this.activePointerId)) return

    this.isDragging = false
    this.activePointerId = null
    this.viewportTarget.classList.remove("is-dragging")

    if (this.viewportTarget.hasPointerCapture?.(event.pointerId)) {
      this.viewportTarget.releasePointerCapture(event.pointerId)
    }
  }

  reset(event) {
    if (event?.target !== this.viewportTarget && !this.viewportTarget.contains(event?.target)) return
    this.fitToViewport()
  }

  fitToViewport() {
    const image = this.imageTarget
    const viewport = this.viewportTarget
    const naturalWidth = image.naturalWidth
    const naturalHeight = image.naturalHeight

    if (!naturalWidth || !naturalHeight) return

    const padding = 32
    const availableWidth = Math.max(viewport.clientWidth - padding, 1)
    const availableHeight = Math.max(viewport.clientHeight - padding, 1)
    const fitScale = Math.min(availableWidth / naturalWidth, availableHeight / naturalHeight)

    this.scale = this.clampScale(fitScale)
    this.translateX = (viewport.clientWidth - naturalWidth * this.scale) / 2
    this.translateY = (viewport.clientHeight - naturalHeight * this.scale) / 2
    this.fitted = true
    this.applyTransform()
  }

  applyTransform() {
    this.stageTarget.style.transform = `translate(${this.translateX}px, ${this.translateY}px) scale(${this.scale})`
  }

  clampScale(value) {
    return Math.min(this.maxScaleValue, Math.max(this.minScaleValue, value))
  }

  shouldPan(event) {
    return event.target === this.viewportTarget || this.viewportTarget.contains(event.target)
  }
}