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

  connect() {
    this.dragType = null

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

  disconnect() {
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

  applyBannerLayout(position) {
    if (
      ![
        "top",
        "background",
        "bottom"
      ].includes(position)
    ) {
      return
    }

    const frame =
      this.sectionFrame()

    if (!frame) return

    frame.classList.remove(
      "section-frame--top",
      "section-frame--background",
      "section-frame--bottom"
    )

    frame.classList.add(
      `section-frame--${position}`
    )

    this.save({
      banner_layout: position
    })

    const message = {
      top: "Imagem movida para cima",
      background: "Imagem aplicada como fundo",
      bottom: "Imagem movida para baixo"
    }[position]

    this.announce(message)
  }

  applyContentLayout(position) {
    const section =
      this.contentSection()

    if (!section) return

    let layout

    if (this.dragType === "media") {
      layout = {
        left: "text_right",
        right: "text_left",
        top: "media_top",
        bottom: "media_bottom"
      }[position]
    }

    if (this.dragType === "content") {
      layout = {
        left: "text_left",
        right: "text_right",
        top: "media_bottom",
        bottom: "media_top"
      }[position]
    }

    if (!layout) return

    const prefix =
      section.classList.contains(
        "hero-section"
      ) ?
        "hero-section" :
        "text-image-section"

    section.classList.remove(
      `${prefix}--text_left`,
      `${prefix}--text_right`,
      `${prefix}--media_top`,
      `${prefix}--media_bottom`
    )

    section.classList.add(
      `${prefix}--${layout}`
    )

    this.save({
      media_layout: layout
    })

    this.announce(
      "Composição atualizada"
    )
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
      ".hero-section, .text-image-section"
    )
  }

  async save(fields) {
    if (!this.hasUpdateUrlValue) return

    const formData =
      new FormData()

    Object.entries(fields).forEach(
      ([key, value]) => {
        formData.append(
          `section[${key}]`,
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

      if (!data.success) {
        throw new Error()
      }
    } catch (_error) {
      this.announce(
        "Não foi possível salvar",
        true
      )
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
