import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "sample", "select", "option"]

  connect() {
    if (this.hasSelectTarget) this.selectFont()
  }

  selectFont() {
    this.sampleTarget.style.fontFamily = this.selectTarget.selectedOptions[0].dataset.fontStack
  }

  filter(event) {
    const query = event.target.value.toLocaleLowerCase()
    this.optionTargets.forEach(option => { option.hidden = !option.textContent.toLocaleLowerCase().includes(query) })
  }

  choose(event) {
    this.nameTarget.textContent = event.target.dataset.fontName
    this.sampleTarget.style.fontFamily = event.target.dataset.fontStack
    const details = this.element.querySelector("details")
    details.open = false
    details.querySelector("summary").focus()
  }
}
