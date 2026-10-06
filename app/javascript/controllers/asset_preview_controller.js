import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "canvas",
    "image",
    "input",
    "empty",
    "focus",
    "x",
    "y",
    "zoom",
    "zoomLabel",
    "positionLabel"
  ]

  connect() {
    this.dragging = false
    this.objectUrl = null
    this.update()
  }

  disconnect() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
    }
  }

  fileChanged() {
    const file = this.inputTarget.files?.[0]

    if (!file) return

    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
    }

    this.objectUrl = URL.createObjectURL(file)

    this.imageTarget.src = this.objectUrl
    this.imageTarget.classList.remove("is-hidden")

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.add("is-hidden")
    }

    this.update()
  }

  startPosition(event) {
    if (this.imageTarget.classList.contains("is-hidden")) return

    event.preventDefault()

    this.dragging = true
    this.canvasTarget.classList.add("is-dragging")

    this.canvasTarget.setPointerCapture(event.pointerId)
    this.setPosition(event)
  }

  movePosition(event) {
    if (!this.dragging) return

    this.setPosition(event)
  }

  endPosition(event) {
    this.dragging = false
    this.canvasTarget.classList.remove("is-dragging")

    if (this.canvasTarget.hasPointerCapture(event.pointerId)) {
      this.canvasTarget.releasePointerCapture(event.pointerId)
    }
  }

  setPosition(event) {
    const rect = this.canvasTarget.getBoundingClientRect()

    const x = ((event.clientX - rect.left) / rect.width) * 100
    const y = ((event.clientY - rect.top) / rect.height) * 100

    this.xTarget.value = Math.round(this.clamp(x, 0, 100))
    this.yTarget.value = Math.round(this.clamp(y, 0, 100))

    this.update()
  }

  zoomIn() {
    this.changeZoom(0.05)
  }

  zoomOut() {
    this.changeZoom(-0.05)
  }

  changeZoom(change) {
    const current = Number(this.zoomTarget.value || 1)
    const next = this.clamp(current + change, 0.25, 3)

    this.zoomTarget.value = next.toFixed(2)

    this.update()
  }

  setPreset(event) {
    this.xTarget.value = Number(event.currentTarget.dataset.x)
    this.yTarget.value = Number(event.currentTarget.dataset.y)

    this.update()
  }

  reset() {
    this.xTarget.value = 50
    this.yTarget.value = 50
    this.zoomTarget.value = 1

    this.update()
  }

  update() {
    const x = Number(this.xTarget.value || 50)
    const y = Number(this.yTarget.value || 50)
    const zoom = Number(this.zoomTarget.value || 1)

    if (this.hasImageTarget) {
      this.imageTarget.style.objectPosition = `${x}% ${y}%`
      this.imageTarget.style.transform = `scale(${zoom})`
      this.imageTarget.style.transformOrigin = `${x}% ${y}%`
    }

    if (this.hasFocusTarget) {
      this.focusTarget.style.left = `${x}%`
      this.focusTarget.style.top = `${y}%`
    }

    if (this.hasZoomLabelTarget) {
      this.zoomLabelTarget.textContent = `${Math.round(zoom * 100)}%`
    }

    if (this.hasPositionLabelTarget) {
      this.positionLabelTarget.textContent = `${Math.round(x)}% × ${Math.round(y)}%`
    }
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }
}
