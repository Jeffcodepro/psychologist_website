import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "description", "previewTitle", "previewDescription", "count", "template"]
  static values = { title: String, description: String, templates: Array }
  connect() { this.refresh() }
  get selectedTemplate() {
    return this.templatesValue[Number(this.templateTarget.value)] || { title: this.titleValue, description: this.descriptionValue }
  }
  useTitle() { this.titleTarget.value = this.selectedTemplate.title; this.changed(this.titleTarget) }
  useDescription() { this.descriptionTarget.value = this.selectedTemplate.description; this.changed(this.descriptionTarget) }
  applyTemplate() { this.useTitle(); this.useDescription() }
  changed(input) { input.dispatchEvent(new Event("input", { bubbles: true })); this.refresh() }
  refresh() {
    this.previewTitleTarget.textContent = this.titleTarget.value || this.selectedTemplate.title
    this.previewDescriptionTarget.textContent = this.descriptionTarget.value || this.selectedTemplate.description
    this.countTarget.textContent = `${this.titleTarget.value.length} caracteres no título · ${this.descriptionTarget.value.length} na descrição. O Google pode adaptar a exibição.`
  }
}
