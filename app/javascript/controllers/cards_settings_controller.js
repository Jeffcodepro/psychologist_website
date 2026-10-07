import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "deviceButton", "deviceLabel", "preview"]
  static values = { sectionId: Number }
  connect() { this.device = "desktop"; this.refresh() }
  chooseDevice(event) { this.device = event.currentTarget.dataset.device; this.refresh() }
  panel(device = this.device) { return this.panelTargets.find(panel => panel.dataset.device === device) }
  value(key, device = this.device) {
    return this.panel(device).querySelector(`[data-card-setting="${key}"]`)?.value || this.panel("desktop").querySelector(`[data-card-setting="${key}"]`)?.value
  }
  config(device) {
    return { orientation: this.value("orientation", device), wrap: this.value("wrap", device) === "true", alignment: this.value("alignment", device), autoplay: this.value("autoplay", device) === "true", seconds: Number(this.value("seconds", device)), columns: Number(this.value("columns", device)) }
  }
  orientationChanged(event) { this.panel().querySelector('[data-card-setting="orientation"]').value = event.currentTarget.dataset.orientation; this.refresh() }
  inherit() {
    this.panel().querySelectorAll('[data-card-setting]:not([data-card-setting="columns"])').forEach(field => {
      if (field.tomselect) field.tomselect.setValue("", true)
      else field.value = ""
    })
    this.refresh()
  }
  refresh() {
    this.device ||= "desktop"
    this.panelTargets.forEach(panel => { panel.hidden = panel.dataset.device !== this.device })
    this.deviceButtonTargets.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.device === this.device)))
    this.deviceLabelTarget.textContent = { desktop: "Desktop", tablet: "Tablet", mobile: "Mobile" }[this.device]
    const settings = this.config(this.device)
    this.panel().querySelectorAll('[data-orientation]').forEach(button => {
      const selected = button.dataset.orientation === settings.orientation
      button.classList.toggle("is-selected", selected); button.setAttribute("aria-pressed", selected)
    })
    const carousel = settings.orientation === "horizontal" && !settings.wrap
    this.previewTarget.classList.toggle("is-horizontal", settings.orientation === "horizontal")
    this.previewTarget.classList.toggle("is-vertical", settings.orientation === "vertical")
    this.previewTarget.classList.toggle("is-carousel", carousel)
    this.previewTarget.style.setProperty("--cards-preview-columns", carousel ? { desktop: 3, tablet: 2, mobile: 1 }[this.device] : settings.columns)
  }
}
