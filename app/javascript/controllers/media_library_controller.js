import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "slide", "primary", "removeFlag", "removeButton", "removeNote"]
  static values = { token: String }

  removePrimary() {
    const remove = this.removeFlagTarget.value !== "1"
    this.removeFlagTarget.value = remove ? "1" : "0"
    this.primaryTarget.hidden = remove
    this.removeNoteTarget.hidden = !remove
    this.removeButtonTarget.textContent = remove ? "Desfazer remoção" : this.removeButtonTarget.dataset.label
  }

  add() {
    const id = `${Date.now()}${Math.floor(Math.random() * 1000000)}`
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll(this.tokenValue, id))
    const slide = this.listTarget.lastElementChild
    slide.querySelector('input[name$="[position]"]').value = this.slideTargets.length
    slide.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  remove(event) {
    const slide = event.currentTarget.closest(".media-library__slide")
    slide.querySelector("[data-destroy-slide]").value = "1"
    slide.hidden = true
  }
}
