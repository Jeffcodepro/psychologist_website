import { Controller } from "@hotwired/stimulus"

// Match the link to the rendered object, including zoom, position and clipping.
export default class extends Controller {
  static targets = ["frame", "image", "link"]

  connect() {
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(this.frameTarget)
    this.resize()
  }

  disconnect() { this.observer?.disconnect() }

  resize() {
    const image = this.imageTarget, frame = this.frameTarget
    if (!image.naturalWidth || !frame.clientWidth) return
    const style = getComputedStyle(image)
    const zoom = Number(getComputedStyle(frame).getPropertyValue("--site-logo-zoom")) || 1
    const [x, y] = style.objectPosition.split(" ").map(value => parseFloat(value) / 100)
    const width = frame.clientWidth, height = frame.clientHeight
    const fit = Math.min(width / image.naturalWidth, height / image.naturalHeight)
    const imageWidth = image.naturalWidth * fit * zoom
    const imageHeight = image.naturalHeight * fit * zoom
    const left = Math.max(0, (width - imageWidth) * x)
    const top = Math.max(0, (height - imageHeight) * y)
    const right = Math.min(width, (width - imageWidth) * x + imageWidth)
    const bottom = Math.min(height, (height - imageHeight) * y + imageHeight)
    Object.assign(this.linkTarget.style, { left: `${left}px`, top: `${top}px`,
      width: `${right - left}px`, height: `${bottom - top}px` })
  }
}
