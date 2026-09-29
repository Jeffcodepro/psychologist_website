import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.syncDevice = () => this.activate(document.documentElement.dataset.editingDevice || "desktop")
    document.addEventListener("cms:editing-device", this.syncDevice)
    this.syncDevice()
  }

  disconnect() {
    document.removeEventListener("cms:editing-device", this.syncDevice)
  }

  choose(event) { this.activate(event.currentTarget.dataset.device) }

  activate(device) {
    this.buttonTargets.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.device === device)))
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.device !== device
      if (panel.tagName === "DETAILS" && !panel.hidden) panel.open = true
    })
  }
}
