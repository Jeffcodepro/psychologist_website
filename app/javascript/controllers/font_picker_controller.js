import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sample", "select"]
  connect() { this.selectFont() }
  selectFont() {
    this.sampleTarget.style.fontFamily = this.selectTarget.selectedOptions[0]?.dataset.fontStack || "inherit"
  }
}
