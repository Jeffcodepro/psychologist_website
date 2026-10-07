import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { youtube: String, url: String, title: String }

  connect() {
    this.onVisibility = () => { if (document.hidden) this.stop() }
    document.addEventListener("visibilitychange", this.onVisibility)
    this.observer = new IntersectionObserver(entries => { if (!entries[0].isIntersecting) this.stop() })
    this.observer.observe(this.element)
  }

  disconnect() { this.stop(); this.observer?.disconnect(); document.removeEventListener("visibilitychange", this.onVisibility) }

  play(event) {
    event.preventDefault(); event.stopPropagation()
    if (!this.youtubeValue && !this.urlValue) return
    this.stop()
    // A full player keeps controls accessible even in a cropped photo or small card.
    this.dialog = document.createElement("dialog")
    this.dialog.className = "cms-video-dialog"
    this.dialog.setAttribute("aria-label", this.titleValue || "Vídeo")
    const close = document.createElement("button")
    close.type = "button"; close.className = "cms-video-dialog__close"; close.textContent = "×"; close.setAttribute("aria-label", "Fechar vídeo")
    close.addEventListener("click", () => this.stop())
    const player = document.createElement(this.youtubeValue ? "iframe" : "video")
    if (this.youtubeValue) {
      const params = new URLSearchParams({ autoplay: "1", playsinline: "1", rel: "0", origin: location.origin })
      player.src = `https://www.youtube-nocookie.com/embed/${this.youtubeValue}?${params}`
      player.title = this.titleValue || "Vídeo do YouTube"
      player.allow = "autoplay; encrypted-media; picture-in-picture; fullscreen"
      player.allowFullscreen = true
      player.referrerPolicy = "strict-origin-when-cross-origin"
    } else {
      player.src = this.urlValue; player.controls = true; player.playsInline = true; player.preload = "metadata"
    }
    this.dialog.append(close, player)
    this.dialog.addEventListener("cancel", event => { event.preventDefault(); this.stop() })
    this.dialog.addEventListener("click", event => { if (event.target === this.dialog) this.stop() })
    document.body.append(this.dialog)
    this.dialog.showModal(); close.focus()
    if (!this.youtubeValue) player.play().catch(() => {})
    this.element.dispatchEvent(new CustomEvent("cms-video:play", { bubbles: true }))
  }

  stop() {
    if (!this.dialog) return
    this.dialog.querySelector("video")?.pause()
    this.dialog.querySelector("iframe")?.remove()
    this.dialog.close(); this.dialog.remove(); this.dialog = null
    if (this.element.isConnected) this.element.querySelector("button")?.focus({ preventScroll: true })
  }
}
