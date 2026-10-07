import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { config: Object }
  connect() { this.onResize = () => this.render(); window.addEventListener("resize", this.onResize); this.render() }
  disconnect() { window.removeEventListener("resize", this.onResize) }
  configValueChanged() { if (this.element.isConnected) this.render() }
  render() {
    const device = innerWidth <= 600 ? "mobile" : innerWidth <= 1024 ? "tablet" : "desktop"
    const settings = this.configValue[device]
    if (!settings) return
    const carousel = settings.orientation === "horizontal" && !settings.wrap
    this.element.dataset.cardsMode = carousel ? "carousel" : settings.orientation === "vertical" ? "vertical" : "grid"
    for (const value of ["horizontal", "vertical", "left", "center", "right"]) this.element.classList.remove(`card-collection--${value}`)
    this.element.classList.add(`card-collection--${settings.orientation}`, `card-collection--${settings.alignment}`)
    this.element.style.setProperty("--cards-columns", settings.columns)
    const track = this.element.querySelector("[data-controller=cards-carousel]")
    if (track) {
      track.dataset.cardsCarouselEnabledValue = String(carousel)
      track.dataset.cardsCarouselAutoplayValue = String(settings.autoplay)
      track.dataset.cardsCarouselDelayValue = String(settings.seconds * 1000)
    }
  }
}
