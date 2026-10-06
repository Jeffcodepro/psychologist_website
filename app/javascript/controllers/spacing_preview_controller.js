import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "viewport", "status"]
  static values = { url: String, device: String }

  connect() {
    if (!this.urlValue) return
    this.form = this.element.closest("form")
    this.schedule = () => {
      clearTimeout(this.timer)
      if (!this.element.getClientRects().length) return
      this.request?.abort()
      this.timer = setTimeout(() => this.refresh(), 300)
    }
    this.form.addEventListener("input", this.schedule)
    this.form.addEventListener("change", this.schedule)
    this.observer = new ResizeObserver(() => {
      this.resize()
      const visible = this.element.getClientRects().length > 0
      if (visible && !this.wasVisible) this.schedule()
      this.wasVisible = visible
    })
    this.observer.observe(this.element)
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.form?.removeEventListener("input", this.schedule)
    this.form?.removeEventListener("change", this.schedule)
    this.observer?.disconnect()
  }

  async refresh() {
    if (!this.urlValue) return
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    const data = new FormData(this.form)
    // Only text/layout values are needed; never upload images or change stored records.
    const body = new URLSearchParams()
    for (const [key, value] of data.entries()) {
      if (typeof value === "string" && key.startsWith("section[")) body.append(key, value)
    }
    this.statusTarget.textContent = "Atualizando prévia…"
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "same-origin", body, signal: request.signal,
        headers: { Accept: "text/html", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      if (!response.ok) throw new Error()
      const html = await response.text()
      if (request.signal.aborted) return
      this.frameTarget.srcdoc = html
      this.loaded = true
      this.statusTarget.textContent = "Prévia atualizada. Nada foi salvo ainda."
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = "Não foi possível atualizar a prévia. Confira os valores e tente novamente."
    }
  }

  resize() {
    if (!this.hasFrameTarget) return
    const width = { desktop: 1200, tablet: 800, mobile: 390 }[this.deviceValue]
    const available = this.viewportTarget.clientWidth
    if (!available) return
    const scale = Math.min(1, available / width)
    this.frameTarget.style.width = `${width}px`
    this.frameTarget.style.transform = `scale(${scale})`
    const height = Math.max(200, this.frameTarget.contentDocument?.body?.scrollHeight || 400)
    this.frameTarget.style.height = `${height}px`
    this.viewportTarget.style.height = `${Math.min(650, height * scale)}px`
  }
}
