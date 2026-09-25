import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.blocks = []
    this.onScroll = () => {
      if (!this.frame) this.frame = requestAnimationFrame(() => { this.frame = null; this.render() })
    }
    this.onMotion = () => { this.restore(); if (!this.motion.matches) this.prepare() }
    this.beforeCache = () => this.restore()
    this.motion.addEventListener("change", this.onMotion)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll)
    if (!this.motion.matches) this.prepare()
  }

  prepare() {
    this.element.querySelectorAll(".section-heading, .section-body p, .appointment-section__intro h2, .appointment-section__intro > p").forEach(element => {
      const original = element.innerHTML
      const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT)
      const nodes = []
      while (walker.nextNode()) nodes.push(walker.currentNode)
      nodes.forEach(node => {
        const fragment = document.createDocumentFragment()
        node.textContent.split(/(\s+)/).forEach(word => {
          if (!word.trim()) fragment.append(document.createTextNode(word))
          else { const span = document.createElement("span"); span.className = "reveal-word"; span.textContent = word; fragment.append(span) }
        })
        node.replaceWith(fragment)
      })
      this.blocks.push({ element, original, words: [...element.querySelectorAll(".reveal-word")] })
    })
    this.render()
  }

  render() {
    const height = innerHeight
    this.blocks.forEach(({ element, words }) => {
      const rect = element.getBoundingClientRect()
      const enter = (height * .96 - rect.top) / Math.min(height * .30, rect.height + 110)
      const leave = (rect.bottom - 65) / Math.min(height * .17, rect.height + 45)
      words.forEach((word, index) => {
        const offset = words.length > 1 ? index / (words.length - 1) : 0
        const opacity = Math.max(0, Math.min(1, enter * 1.45 - offset * .45, leave * 1.35 - (1 - offset) * .35))
        word.style.opacity = opacity
        word.style.transform = `translateY(${(1 - opacity) * (enter < leave ? 7 : -7)}px)`
      })
    })
  }

  restore() { this.blocks.forEach(({ element, original }) => { element.innerHTML = original }); this.blocks = [] }
  disconnect() {
    cancelAnimationFrame(this.frame)
    this.restore()
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.motion.removeEventListener("change", this.onMotion)
  }
}
