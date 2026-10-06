import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "track", "pagination", "position", "range", "counter"]
  static values = { autoplay: { type: Boolean, default: true }, delay: { type: Number, default: 5000 }, pageLabel: { type: String, default: "Página" } }

  connect() {
    this.connected = true
    this.timer = null
    this.pausedByUser = false
    this.keyboardFocused = false
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.mobile = matchMedia("(max-width: 600px)")
    this.onPlaybackChange = () => this.syncAutoplay()
    this.onBreakpointChange = () => this.fitCards()
    this.resizeObserver = new ResizeObserver(() => this.fitCards())
    this.resizeObserver.observe(this.element.parentElement)
    document.addEventListener("visibilitychange", this.onPlaybackChange)
    this.motion.addEventListener("change", this.onPlaybackChange)
    this.mobile.addEventListener("change", this.onBreakpointChange)
    window.addEventListener("resize", this.onBreakpointChange)
    this.settingsObserver = new MutationObserver(() => this.fitCards())
    this.settingsObserver.observe(this.element.parentElement, { attributes: true, attributeFilter: ["style"] })
    this.fitCards()
  }

  disconnect() {
    this.connected = false
    this.resizeObserver.disconnect()
    this.settingsObserver.disconnect()
    window.removeEventListener("resize", this.onBreakpointChange)
    cancelAnimationFrame(this.layoutFrame)
    this.stopAutoplay()
    document.removeEventListener("visibilitychange", this.onPlaybackChange)
    this.motion.removeEventListener("change", this.onPlaybackChange)
    this.mobile.removeEventListener("change", this.onBreakpointChange)
  }

  delayValueChanged() { if (this.connected) this.restartAutoplay() }
  autoplayValueChanged() { if (this.connected) this.syncAutoplay() }

  fitCards() {
    const count = this.trackTarget.children.length
    const gap = parseFloat(getComputedStyle(this.trackTarget).columnGap) || 0
    const width = this.element.parentElement.clientWidth
    // Restore the automatic compact layout. Grid columns belong to wrapped
    // rows; a legacy "1 column" value must not stretch carousel cards.
    this.perPage = this.mobile.matches ? 1 : Math.max(1, Math.floor((width + gap) / (300 + gap)))
    this.element.style.setProperty("--carousel-columns", this.perPage)
    this.fits = count <= this.perPage
    this.element.classList.toggle("is-overflowing", !this.fits)
    this.element.querySelectorAll(".compact-carousel__arrow").forEach(button => { button.hidden = this.fits })
    if (this.fits) this.viewportTarget.scrollTo({ left: 0, behavior: "instant" })
    cancelAnimationFrame(this.layoutFrame)
    this.layoutFrame = requestAnimationFrame(() => {
      const maxScroll = Math.max(0, this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth)
      const step = this.cardStep() * (this.mobile.matches ? this.perPage : 1)
      this.offsets = [0]
      if (step > 0) for (let offset = step; offset < maxScroll - 2; offset += step) this.offsets.push(offset)
      if (maxScroll > 2) this.offsets.push(maxScroll)
      this.renderNavigation()
      this.scrolled()
      this.syncAutoplay()
    })
  }

  renderNavigation() {
    this.paginationTarget.hidden = this.fits || !this.mobile.matches
    this.positionTarget.hidden = this.fits || this.mobile.matches
    this.rangeTarget.max = this.offsets.length - 1
    if (this.paginationTarget.children.length === this.offsets.length) return
    const fragment = document.createDocumentFragment()
    this.offsets.forEach((_, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "compact-carousel__dot"
      button.dataset.pageIndex = index
      button.dataset.action = "cards-carousel#goToPage"
      button.setAttribute("aria-label", `${this.pageLabelValue} ${index + 1}`)
      button.setAttribute("aria-controls", this.viewportTarget.id)
      fragment.append(button)
    })
    this.paginationTarget.replaceChildren(fragment)
  }

  scrolled() {
    if (!this.offsets?.length) return
    const left = this.viewportTarget.scrollLeft
    this.pageIndex = this.offsets.reduce((best, offset, index) => Math.abs(offset - left) < Math.abs(this.offsets[best] - left) ? index : best, 0)
    Array.from(this.paginationTarget.children).forEach((button, index) => {
      if (index === this.pageIndex) button.setAttribute("aria-current", "true")
      else button.removeAttribute("aria-current")
    })
    this.rangeTarget.value = this.pageIndex
    const first = Math.min(this.trackTarget.children.length, Math.round(left / this.cardStep()) + 1) || 1
    const last = Math.min(first + this.perPage - 1, this.trackTarget.children.length)
    this.counterTarget.textContent = `${first}–${last} / ${this.trackTarget.children.length}`
    this.rangeTarget.setAttribute("aria-valuetext", this.counterTarget.textContent)
  }

  // Direct selection holds the chosen content; arrows keep the configured autoplay.
  seek(event) { this.pause(); this.scrollToPage(Number(event.currentTarget.value), "instant") }
  goToPage(event) { this.pause(); this.scrollToPage(Number(event.currentTarget.dataset.pageIndex)) }
  next() { this.move(1); this.restartAutoplay() }
  previous() { this.move(-1); this.restartAutoplay() }
  move(direction) {
    if (!this.offsets?.length || this.fits) return
    this.scrollToPage((this.pageIndex + direction + this.offsets.length) % this.offsets.length)
  }
  scrollToPage(index, behavior = this.motion.matches ? "instant" : "smooth") {
    if (!Number.isInteger(index) || this.offsets?.[index] === undefined) return
    this.pageIndex = index
    this.viewportTarget.scrollTo({ left: this.offsets[index], behavior })
  }
  cardStep() {
    const card = this.trackTarget.firstElementChild
    if (!card) return 0
    return card.getBoundingClientRect().width + (parseFloat(getComputedStyle(this.trackTarget).columnGap) || 0)
  }
  focusEntered(event) { this.keyboardFocused = event.target.matches(":focus-visible"); this.syncAutoplay() }
  focusLeft(event) { if (!this.element.contains(event.relatedTarget)) { this.keyboardFocused = false; this.syncAutoplay() } }
  pause() { this.pausedByUser = true; this.syncAutoplay() }
  syncAutoplay() {
    if (!this.connected) return
    if (!this.autoplayValue || this.fits || this.pausedByUser || this.keyboardFocused || this.motion.matches || document.hidden) { this.stopAutoplay(); return }
    if (this.timer == null) this.timer = setInterval(() => this.move(1), this.delayValue)
  }
  stopAutoplay() { clearInterval(this.timer); this.timer = null }
  restartAutoplay() { this.stopAutoplay(); this.syncAutoplay() }
}
