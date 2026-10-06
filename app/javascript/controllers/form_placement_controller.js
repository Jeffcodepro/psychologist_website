import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["position", "alignment", "choice"]
  static values = { position: String, alignment: String }
  connect() { this.refresh() }
  choose(event) {
    const { position, alignment } = event.currentTarget.dataset
    this.positionTarget.value = position
    this.alignmentTarget.value = alignment
    for (const field of [this.positionTarget, this.alignmentTarget]) field.dispatchEvent(new Event("change", { bubbles: true }))
    this.refresh()
  }
  refresh() {
    const position = this.positionTarget.value || this.positionValue
    const alignment = this.alignmentTarget.value || this.alignmentValue
    this.choiceTargets.forEach(choice => choice.setAttribute("aria-pressed", choice.dataset.position === position && (["left", "right"].includes(position) || choice.dataset.alignment === alignment)))
  }
}
