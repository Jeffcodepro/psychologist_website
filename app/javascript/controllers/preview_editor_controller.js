import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.handleEscape = this.handleEscape.bind(this)
    this.beforeCache = () => this.close()
    document.addEventListener("keydown", this.handleEscape)
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.body.classList.remove("preview-editor-is-open")
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    const panelId = event.currentTarget.dataset.panelId?.trim()
    const panel = this.panelTargets.find(target => target.id === panelId)
    if (!panel) return

    this.closePanels()
    this.opener = event.currentTarget
    document.dispatchEvent(new CustomEvent("cms:editing-device"))
    panel.hidden = false
    if (this.hasBackdropTarget) this.backdropTarget.hidden = false
    document.body.classList.add("preview-editor-is-open")
    panel.querySelector(".preview-editor__close")?.focus({ preventScroll: true })
  }

  close(event) {
    event?.preventDefault()
    this.closePanels()
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true
    document.body.classList.remove("preview-editor-is-open")
    if (this.opener?.isConnected) this.opener.focus({ preventScroll: true })
    this.opener = null
  }

  closePanels() {
    this.panelTargets.forEach(panel => { panel.hidden = true })
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.panelTargets.some(panel => !panel.hidden)) this.close()
  }
}
