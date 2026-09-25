import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel",
    "backdrop"
  ]

  connect() {
    this.handleEscape =
      this.handleEscape.bind(this)

    document.addEventListener(
      "keydown",
      this.handleEscape
    )
  }

  disconnect() {
    document.removeEventListener(
      "keydown",
      this.handleEscape
    )
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const panelId =
      event.currentTarget
        .dataset
        .panelId
        ?.trim()

    if (!panelId) {
      console.error(
        "Panel ID não encontrado."
      )

      return
    }

    this.closePanels()

    const panel =
      document.getElementById(
        panelId
      )

    if (!panel) {
      console.error(
        `Painel ${panelId} não encontrado.`
      )

      return
    }

    document.dispatchEvent(new CustomEvent("cms:editing-device"))
    panel.hidden = false

    if (this.hasBackdropTarget) {
      this.backdropTarget.hidden =
        false
    }

    document.body.classList.add(
      "preview-editor-is-open"
    )
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    this.closePanels()

    if (this.hasBackdropTarget) {
      this.backdropTarget.hidden =
        true
    }

    document.body.classList.remove(
      "preview-editor-is-open"
    )
  }

  closePanels() {
    this.panelTargets.forEach(
      (panel) => {
        panel.hidden = true
      }
    )
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
