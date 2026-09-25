import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "sample", "select"]

  connect() {
    if (this.hasSelectTarget) this.selectFont()
  }

  selectFont() {
    this.sampleTarget.style.fontFamily = this.selectTarget.selectedOptions[0].dataset.fontStack
  }

  choose(event) {
    this.nameTarget.textContent = event.target.dataset.fontName
    this.sampleTarget.style.fontFamily = event.target.dataset.fontStack
    const details = this.element.querySelector("details")
    details.open = false
    details.querySelector("summary").focus()
  }
}
