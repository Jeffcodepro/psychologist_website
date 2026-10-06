import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "picker"]
  static values = { default: String }
  connect() { this.sync() }
  pick() {
    this.fieldTarget.value = this.pickerTarget.value
    this.fieldTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
  sync() {
    const value = this.fieldTarget.value || this.defaultValue
    if (this.pickerTarget.type !== "color" || /^#[0-9a-f]{6}$/i.test(value)) this.pickerTarget.value = value
  }
}
