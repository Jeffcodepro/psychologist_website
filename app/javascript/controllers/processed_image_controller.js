import { Controller } from "@hotwired/stimulus"

// Cloudinary can return 423 while the first background removal is processing.
export default class extends Controller {
  static values = { original: String }
  connect() {
    this.attempt = 0
    if (this.element.complete && !this.element.naturalWidth) this.retryImage()
  }
  disconnect() { clearTimeout(this.timer) }
  loaded() { clearTimeout(this.timer) }
  retryImage() {
    clearTimeout(this.timer)
    if (this.fallback) return
    if (this.attempt++ >= 4) {
      this.fallback = true
      this.element.removeAttribute("srcset")
      this.element.src = this.originalValue
      return
    }
    this.timer = setTimeout(() => {
      const src = this.element.src, srcset = this.element.srcset
      this.element.removeAttribute("srcset")
      this.element.removeAttribute("src")
      this.element.src = src
      if (srcset) this.element.srcset = srcset
    }, this.attempt * 1500)
  }
}
