import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "notice"]

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
    this.noticeTarget.textContent = device === "desktop" ?
      "Editando a aparência base do desktop. Tablet e mobile usam esta base nos campos que não foram personalizados." :
      `Editando somente ${device === "mobile" ? "mobile" : "tablet"}. Estes ajustes não alteram o desktop. Deixe um campo vazio para usar o padrão.`
  }
}
