import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "button", "counter"]
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.index = 0
    this.pausedByUser = false
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.onVisibility = () => document.hidden ? this.pause() : this.resume()
    this.onMotion = () => this.motion.matches ? this.pause() : this.resume()
    document.addEventListener("visibilitychange", this.onVisibility)
    this.motion.addEventListener("change", this.onMotion)
    this.resume()
  }

  disconnect() {
    this.pause()
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.motion.removeEventListener("change", this.onMotion)
  }

  pause() { clearInterval(this.timer); this.timer = null }

  resume() {
    this.pause()
    if (this.slideTargets.length < 2 || this.pausedByUser || this.motion.matches || document.hidden || this.element.matches(":focus-within")) return
    this.timer = setInterval(() => this.next(), Math.max(2000, this.delayValue))
  }

  next() {
    this.index = (this.index + 1) % this.slideTargets.length
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("is-active", i === this.index)
      slide.setAttribute("aria-hidden", i !== this.index)
    })
    if (this.hasCounterTarget) this.counterTarget.textContent = `${this.index + 1} / ${this.slideTargets.length}`
  }

  toggle() {
    this.pausedByUser = !this.pausedByUser
    this.buttonTarget.setAttribute("aria-pressed", this.pausedByUser)
    this.buttonTarget.setAttribute("aria-label", this.pausedByUser ? "Retomar troca de imagens" : "Pausar troca de imagens")
    this.buttonTarget.textContent = this.pausedByUser ? "▶" : "Ⅱ"
    this.resume()
  }
}
