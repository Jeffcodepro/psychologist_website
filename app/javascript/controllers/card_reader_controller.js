import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["excerpt", "button", "dialog"]
  connect() {
    this.observer = new ResizeObserver(() => this.measure())
    this.observer.observe(this.excerptTarget)
    document.fonts.ready.then(() => { if (this.element.isConnected) this.measure() })
  }
  disconnect() { this.observer.disconnect(); this.dialogTarget.close() }
  measure() {
    this.buttonTarget.hidden = true
    this.buttonTarget.hidden = this.excerptTarget.scrollHeight <= this.excerptTarget.clientHeight + 1
  }
  open() { this.dialogTarget.showModal() }
  close() { this.dialogTarget.close(); this.buttonTarget.focus() }
  backdrop(event) { if (event.target === this.dialogTarget) { const r = this.dialogTarget.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) this.close() } }
}
