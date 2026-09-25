import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "layoutZones",
    "bannerZones",
    "status"
  ]

  static values = {
    updateUrl: String
  }

  async selectImageLayout(event) {
    if (await this.save({ media_layout: event.target.value })) this.announce("Posição da imagem salva nesta tela")
  }

  selectBannerLayout(event) { this.applyBannerLayout(event.target.value) }

  connect() {
    this.dragType = null
    this.onDevice = () => this.syncSelections()
    document.addEventListener("cms:editing-device", this.onDevice)
    this.syncSelections()

    this.pointerMove = this.pointerMove.bind(this)
    this.pointerUp = this.pointerUp.bind(this)

    document.addEventListener(
      "pointermove",
      this.pointerMove
    )

    document.addEventListener(
      "pointerup",
      this.pointerUp
    )
  }

  syncSelections() {
    const device = document.documentElement.dataset.editingDevice || (innerWidth <= 600 ? "mobile" : innerWidth <= 1024 ? "tablet" : "desktop")
    this.element.querySelectorAll("[data-layout-values]").forEach(select => { select.value = JSON.parse(select.dataset.layoutValues)[device] })
  }

  disconnect() {
    document.removeEventListener("cms:editing-device", this.onDevice)
    document.removeEventListener(
      "pointermove",
      this.pointerMove
    )

    document.removeEventListener(
      "pointerup",
      this.pointerUp
    )
  }

  startMediaDrag(event) {
    this.startDrag("media", event)
  }

  startContentDrag(event) {
    this.startDrag("content", event)
  }

  startBannerDrag(event) {
    this.startDrag("banner", event)
  }

  startDrag(type, event) {
    event.preventDefault()
    event.stopPropagation()

    this.dragType = type

    this.element.classList.add(
      "is-composition-dragging"
    )

    if (type === "banner") {
      if (this.hasBannerZonesTarget) {
        this.bannerZonesTarget.hidden = false
      }

      return
    }

    if (this.hasLayoutZonesTarget) {
      this.layoutZonesTarget.hidden = false
    }
  }

  pointerMove(event) {
    if (!this.dragType) return

    this.clearHoveredZones()

    const element =
      document.elementFromPoint(
        event.clientX,
        event.clientY
      )

    if (!element) return

    const zone =
      element.closest(
        "[data-layout-position], [data-banner-position]"
      )

    if (zone) {
      zone.classList.add("is-hovered")
    }
  }

  pointerUp(event) {
    if (!this.dragType) return

    const element =
      document.elementFromPoint(
        event.clientX,
        event.clientY
      )

    if (this.dragType === "banner") {
      const zone =
        element?.closest(
          "[data-banner-position]"
        )

      if (zone) {
        this.applyBannerLayout(
          zone.dataset.bannerPosition
        )
      }

      this.finishDrag()
      return
    }

    const zone =
      element?.closest(
        "[data-layout-position]"
      )

    if (zone) {
      this.applyContentLayout(
        zone.dataset.layoutPosition
      )
    }

    this.finishDrag()
  }

  chooseBanner(event) {
    event.preventDefault()
    event.stopPropagation()

    const position =
      event.currentTarget.dataset.bannerPosition

    this.applyBannerLayout(position)
    this.finishDrag()
  }

  chooseLayout(event) {
    event.preventDefault()
    event.stopPropagation()

    const position =
      event.currentTarget.dataset.layoutPosition

    this.applyContentLayout(position)
    this.finishDrag()
  }

  async applyBannerLayout(position) {
    if (!["top", "background", "bottom"].includes(position)) return
    if (await this.save({ banner_layout: position })) this.announce("Banner atualizado nesta tela")
  }

  async applyContentLayout(position) {
    if (!this.contentSection()) return
    const layouts = this.dragType === "media" ?
      { left: "text_right", right: "text_left", top: "media_top", bottom: "media_bottom" } :
      { left: "text_left", right: "text_right", top: "media_bottom", bottom: "media_top" }
    const layout = layouts[position]
    if (layout && await this.save({ media_layout: layout })) this.announce("Composição atualizada nesta tela")
  }

  sectionFrame() {
    if (
      this.element.classList.contains(
        "section-frame"
      )
    ) {
      return this.element
    }

    return this.element.closest(
      ".section-frame"
    )
  }

  contentSection() {
    const frame =
      this.sectionFrame()

    if (!frame) return null

    return frame.querySelector(
      ".flexible-section, .hero-section, .text-image-section"
    )
  }

  async save(fields) {
    if (!this.hasUpdateUrlValue) return

    const formData =
      new FormData()

    const device = document.documentElement.dataset.editingDevice ||
      (window.innerWidth <= 600 ? "mobile" : window.innerWidth <= 1024 ? "tablet" : "desktop")

    Object.entries(fields).forEach(
      ([key, value]) => {
        formData.append(
          device === "desktop" ? `section[${key}]` : `section[responsive_settings][${device}][${key}]`,
          value
        )
      }
    )

    try {
      const response =
        await fetch(
          this.updateUrlValue,
          {
            method: "PATCH",
            headers: {
              Accept: "application/json",
              "X-CSRF-Token":
                this.csrfToken()
            },
            credentials: "same-origin",
            body: formData
          }
        )

      if (!response.ok) {
        throw new Error()
      }

      const data =
        await response.json()

      if (!data.success) throw new Error()
      const frame = this.sectionFrame()
      frame.style.cssText = data.style_variables
      frame.querySelectorAll("[data-layout-values]").forEach(select => {
        const key = select.dataset.action.includes("selectImageLayout") ? "media_layout" : "banner_layout"
        if (fields[key]) {
          const values = JSON.parse(select.dataset.layoutValues)
          values[device] = fields[key]
          select.dataset.layoutValues = JSON.stringify(values)
        }
      })
      frame.dataset.bannerTablet = data.banner_tablet
      frame.dataset.bannerMobile = data.banner_mobile
      frame.classList.remove("section-frame--top", "section-frame--background", "section-frame--bottom")
      frame.classList.add(`section-frame--${data.banner_layout}`)
      return true
    } catch (_error) {
      this.announce(
        "Não foi possível salvar",
        true
      )
      return false
    }
  }

  csrfToken() {
    const localToken =
      document.querySelector(
        'meta[name="csrf-token"]'
      )?.content

    if (localToken) {
      return localToken
    }

    try {
      return (
        window.parent.document
          .querySelector(
            'meta[name="csrf-token"]'
          )
          ?.content || ""
      )
    } catch (_error) {
      return ""
    }
  }

  announce(message, error = false) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent =
      message

    this.statusTarget.classList.toggle(
      "is-error",
      error
    )

    this.statusTarget.classList.add(
      "is-visible"
    )

    clearTimeout(
      this.statusTimer
    )

    this.statusTimer =
      setTimeout(() => {
        this.statusTarget.classList.remove(
          "is-visible"
        )
      }, 1800)
  }

  clearHoveredZones() {
    this.element
      .querySelectorAll(
        ".is-hovered"
      )
      .forEach((zone) => {
        zone.classList.remove(
          "is-hovered"
        )
      })
  }

  finishDrag() {
    this.dragType = null

    this.element.classList.remove(
      "is-composition-dragging"
    )

    if (
      this.hasLayoutZonesTarget
    ) {
      this.layoutZonesTarget.hidden =
        true
    }

    if (
      this.hasBannerZonesTarget
    ) {
      this.bannerZonesTarget.hidden =
        true
    }

    this.clearHoveredZones()
  }
}
