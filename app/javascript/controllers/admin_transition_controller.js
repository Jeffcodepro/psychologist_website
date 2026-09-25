import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.restore = this.restore.bind(this)
    this.restore()
    document.addEventListener("turbo:before-cache", this.restore)
    window.addEventListener("pageshow", this.restore)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.restore)
    window.removeEventListener("pageshow", this.restore)
  }

  restore() {
    this.element.classList.remove("admin-page--entering", "admin-page--leaving")
    this.element.classList.add("admin-page--ready")
  }
}
