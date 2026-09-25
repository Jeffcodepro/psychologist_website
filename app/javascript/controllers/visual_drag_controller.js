import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zones", "zone", "hint", "ghost", "status"]
  static values = { updateUrl: String, swapUrl: String, sectionId: Number }

  connect() {
    this.movePointer = event => this.move(event)
    this.endPointer = event => this.finish(event)
    this.escape = event => { if (event.key === "Escape") this.cancel() }
    document.addEventListener("pointermove", this.movePointer)
    document.addEventListener("pointerup", this.endPointer)
    document.addEventListener("pointercancel", this.endPointer)
    document.addEventListener("keydown", this.escape)
  }

  disconnect() {
    this.cancel()
    clearTimeout(this.statusTimer)
    document.removeEventListener("pointermove", this.movePointer)
    document.removeEventListener("pointerup", this.endPointer)
    document.removeEventListener("pointercancel", this.endPointer)
    document.removeEventListener("keydown", this.escape)
  }

  start(event) {
    if (event.button !== 0) return
    event.preventDefault()
    this.cancel()
    this.field = event.currentTarget.dataset.moveField
    this.handle = event.currentTarget
    this.origin = { x: event.clientX, y: event.clientY }
    this.pointerY = event.clientY
  }

  keyboard(event) {
    if (!["Enter", " "].includes(event.key)) return
    event.preventDefault()
    this.cancel()
    this.field = event.currentTarget.dataset.moveField
    this.handle = event.currentTarget
    this.showZones()
    this.zoneTargets.find(zone => !zone.hidden)?.focus()
  }

  showZones() {
    this.active = true
    this.zonesTarget.hidden = false
    this.hintTarget.textContent = `${this.handle.textContent.trim()} · solte ou escolha uma posição`
    this.element.classList.add("is-element-dragging")
    const rect = this.element.getBoundingClientRect()
    const top = Math.max(82, rect.top)
    const height = Math.max(220, Math.min(rect.bottom, innerHeight - 16) - top)
    Object.assign(this.zonesTarget.style, { top: `${top}px`, left: `${Math.max(8, rect.left + 8)}px`, width: `${Math.min(innerWidth - 16, rect.width - 16)}px`, height: `${height}px` })
    this.zoneTargets.forEach(zone => {
      const direction = zone.dataset.position
      zone.hidden = this.field === "banner" ? ["left", "right"].includes(direction) : this.field === "image" && direction === "center"
      zone.textContent = this.field === "banner" ? { top: "Banner acima", center: "Imagem de fundo", bottom: "Banner abaixo" }[direction] : { top: "Acima", left: "Esquerda", center: "Centralizar", right: "Direita", bottom: "Abaixo" }[direction]
    })
  }

  move(event) {
    if (!this.origin) return
    if (!this.active && Math.hypot(event.clientX - this.origin.x, event.clientY - this.origin.y) < 5) return
    if (!this.active) { this.showZones(); this.autoScroll() }
    this.pointerY = event.clientY
    this.ghostTarget.hidden = false
    this.ghostTarget.textContent = this.handle.textContent.trim()
    Object.assign(this.ghostTarget.style, { left: `${event.clientX + 14}px`, top: `${event.clientY + 14}px` })
    this.zoneTargets.forEach(zone => zone.classList.remove("is-hovered"))
    this.clearOtherTarget()
    const target = document.elementFromPoint(event.clientX, event.clientY)
    const zone = target?.closest("[data-position]")
    if (zone && this.zonesTarget.contains(zone)) zone.classList.add("is-hovered")
    const other = target?.closest(".preview-editable-section")
    if (other && other.dataset.sectionId !== String(this.sectionIdValue)) {
      this.otherTarget = other.querySelector(`[data-preview-field="${this.field}"]`)
      this.otherTarget?.classList.add("is-field-highlighted")
      this.otherSection = other.dataset.sectionId
    }
  }

  async finish(event) {
    if (!this.field || !this.origin) return
    if (event.type === "pointercancel") { this.cancel(); return }
    if (!this.active) { this.showZones(); this.origin = null; return }
    const target = document.elementFromPoint(event.clientX, event.clientY)
    const zone = target?.closest("[data-position]")
    if (zone && this.zonesTarget.contains(zone)) await this.apply(zone.dataset.position)
    else if (this.otherTarget && this.otherSection) await this.swap()
    this.cancel()
  }

  async choose(event) { await this.apply(event.currentTarget.dataset.position); this.cancel() }

  fieldsFor(position) {
    if (this.field === "banner") return { banner_layout: { top: "top", center: "background", bottom: "bottom" }[position] }
    if (this.field === "image") return { media_layout: { left: "text_right", right: "text_left", top: "media_top", bottom: "media_bottom" }[position] }
    if (["left", "center", "right"].includes(position)) return { [this.field === "title" ? "title_alignment" : "body_alignment"]: position }
    return { text_order: (this.field === "title") === (position === "top") ? "title_first" : "body_first" }
  }

  async apply(position) {
    const fields = this.fieldsFor(position)
    if (Object.values(fields).some(value => !value)) return
    const device = document.documentElement.dataset.editingDevice || (innerWidth <= 600 ? "mobile" : innerWidth <= 1024 ? "tablet" : "desktop")
    const payload = device === "desktop" ? fields : { responsive_settings: { [device]: fields } }
    try {
      const response = await fetch(this.updateUrlValue, { method: "PATCH", headers: this.headers(), body: JSON.stringify({ section: payload }) })
      if (!response.ok) throw new Error()
      const data = await response.json()
      this.element.style.cssText = data.style_variables
      this.element.dataset.bannerTablet = data.banner_tablet
      this.element.dataset.bannerMobile = data.banner_mobile
      this.element.classList.remove("section-frame--top", "section-frame--background", "section-frame--bottom")
      this.element.classList.add(`section-frame--${data.banner_layout}`)
      const editor = document.getElementById(`preview-editor-${this.sectionIdValue}`)
      Object.entries(fields).forEach(([key, value]) => {
        const name = device === "desktop" ? `section[${key}]` : `section[responsive_settings][${device}][${key}]`
        editor?.querySelectorAll(`[name="${name}"]`).forEach(input => { if (input.type === "radio") input.checked = input.value === value; else input.value = value })
      })
      this.announce("Posição salva nesta tela")
    } catch (_) { this.announce("Não foi possível salvar a posição. Tente novamente.") }
  }

  async swap() {
    try {
      const response = await fetch(this.swapUrlValue, { method: "PATCH", headers: this.headers(), body: JSON.stringify({ source_id: this.sectionIdValue, target_id: this.otherSection, field: this.field }) })
      if (!response.ok) throw new Error()
      window.location.reload()
    } catch (_) { this.announce("Não foi possível mover o conteúdo.") }
  }

  autoScroll() {
    if (!this.active || !this.origin) return
    const offset = this.pointerY < 100 ? -10 : this.pointerY > innerHeight - 75 ? 10 : 0
    if (offset) window.scrollBy({ top: offset, behavior: "instant" })
    this.scrollFrame = requestAnimationFrame(() => this.autoScroll())
  }

  headers() { return { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content } }
  announce(message) { this.statusTarget.textContent = message; clearTimeout(this.statusTimer); this.statusTimer = setTimeout(() => { this.statusTarget.textContent = "" }, 4000) }
  clearOtherTarget() { this.otherTarget?.classList.remove("is-field-highlighted"); this.otherTarget = null; this.otherSection = null }
  cancel() {
    this.clearOtherTarget()
    this.field = null; this.origin = null; this.active = false
    cancelAnimationFrame(this.scrollFrame)
    if (this.hasZonesTarget) this.zonesTarget.hidden = true
    if (this.hasGhostTarget) this.ghostTarget.hidden = true
    this.element.classList.remove("is-element-dragging")
  }
}
