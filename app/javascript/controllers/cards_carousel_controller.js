import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "track", "autoplayControl", "autoplayLabel"]
  static values = {
    autoplay: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }

  connect() {
    this.connected = true
    this.timer = null
    this.pausedByUser = false
    this.keyboardFocused = false
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.onPlaybackChange = () => this.syncAutoplay()
    this.resizeObserver = new ResizeObserver(() => this.fitCards())
    this.resizeObserver.observe(this.viewportTarget)
    document.addEventListener("visibilitychange", this.onPlaybackChange)
    this.motion.addEventListener("change", this.onPlaybackChange)
    this.fitCards()
  }

  disconnect() {
    this.connected = false
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.layoutFrame)
    this.stopAutoplay()
    document.removeEventListener("visibilitychange", this.onPlaybackChange)
    this.motion.removeEventListener("change", this.onPlaybackChange)
  }

  delayValueChanged() { if (this.connected) this.restartAutoplay() }
  autoplayValueChanged() { if (this.connected) this.syncAutoplay() }

  fitCards() {
    const width = this.viewportTarget.clientWidth
    this.element.style.setProperty("--fitted-cards", Math.max(1, Math.min(this.trackTarget.children.length, Math.floor((width + 20) / 300))))
    cancelAnimationFrame(this.layoutFrame)
    this.layoutFrame = requestAnimationFrame(() => {
      this.fits = this.viewportTarget.scrollWidth <= this.viewportTarget.clientWidth + 2
      this.element.querySelectorAll(".compact-carousel__arrow").forEach(button => { button.hidden = this.fits })
      this.syncAutoplay()
    })
  }

  next() { this.move(1); this.restartAutoplay() }
  previous() { this.move(-1); this.restartAutoplay() }

  move(direction) {
    const viewport = this.viewportTarget
    const step = this.cardStep()
    const maxScroll = viewport.scrollWidth - viewport.clientWidth
    if (!step || maxScroll <= 2) return

    const behavior = this.motion.matches ? "instant" : "smooth"
    if (direction > 0 && viewport.scrollLeft >= maxScroll - 8) {
      viewport.scrollTo({ left: 0, behavior })
    } else if (direction < 0 && viewport.scrollLeft <= 8) {
      viewport.scrollTo({ left: maxScroll, behavior })
    } else {
      viewport.scrollBy({ left: step * direction, behavior })
    }
  }

  cardStep() {
    const firstCard = this.trackTarget.querySelector(".psychology-card")
    if (!firstCard) return 0
    const styles = window.getComputedStyle(this.trackTarget)
    return firstCard.getBoundingClientRect().width + parseFloat(styles.columnGap || styles.gap || "0")
  }

  focusEntered(event) {
    // A mouse click on an arrow must not silently disable automatic playback.
    this.keyboardFocused = event.target.matches(":focus-visible")
    this.syncAutoplay()
  }

  focusLeft(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.keyboardFocused = false
    this.syncAutoplay()
  }

  toggleAutoplay() {
    this.pausedByUser = !this.pausedByUser
    if (!this.pausedByUser) this.keyboardFocused = false
    this.syncAutoplay()
  }

  syncAutoplay() {
    if (!this.connected) return
    if (this.hasAutoplayControlTarget) {
      const button = this.autoplayControlTarget
      button.hidden = !this.autoplayValue || this.fits || this.motion.matches
      button.setAttribute("aria-pressed", String(this.pausedByUser))
      button.setAttribute("aria-label", this.pausedByUser ? button.dataset.resumeLabel : button.dataset.pauseLabel)
      this.autoplayLabelTarget.textContent = this.pausedByUser ? button.dataset.resumeText : button.dataset.pauseText
    }
    if (!this.autoplayValue || this.fits || this.pausedByUser || this.keyboardFocused || this.motion.matches || document.hidden) {
      this.stopAutoplay()
      return
    }
    // Hover and layout changes do not reset the configured interval.
    if (this.timer == null) this.timer = window.setInterval(() => this.move(1), this.delayValue)
  }

  stopAutoplay() {
    window.clearInterval(this.timer)
    this.timer = null
  }

  restartAutoplay() {
    this.stopAutoplay()
    this.syncAutoplay()
  }
}
