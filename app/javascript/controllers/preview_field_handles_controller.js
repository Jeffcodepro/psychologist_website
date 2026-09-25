import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["handle"]

  highlight(event) {
    this.clear()
    const button = event.currentTarget
    const section = button.closest(".preview-editable-section")
    this.highlighted = section.querySelector(`[data-preview-field="${button.dataset.field}"]`)
    this.highlighted?.classList.add("is-field-highlighted")
  }

  clear() { this.highlighted?.classList.remove("is-field-highlighted"); this.highlighted = null }
  disconnect() { this.clear() }
}
