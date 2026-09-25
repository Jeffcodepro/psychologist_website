import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "canvas",
    "image",
    "input",
    "empty",
    "focus",
    "x",
    "y",
    "zoom",
    "zoomLabel",
    "overlay",
    "overlayVisual",
    "overlayLabel",
    "positionLabel",
    "bannerLayout",
    "bannerLayoutButton"
  ]

  static values = {
    sectionId: Number
  }

  connect() {
    this.dragging = false
    this.objectUrl = null

    this.update()
    this.updateBannerButtons()
  }

  disconnect() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
    }
  }

  fileChanged() {
    const file =
      this.inputTarget.files?.[0]

    if (!file) return

    if (this.objectUrl) {
      URL.revokeObjectURL(
        this.objectUrl
      )
    }

    this.objectUrl =
      URL.createObjectURL(file)

    this.imageTarget.src =
      this.objectUrl

    this.imageTarget.classList.remove(
      "is-hidden"
    )

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.add(
        "is-hidden"
      )
    }

    this.update()
  }

  startPosition(event) {
    if (
      this.imageTarget.classList.contains(
        "is-hidden"
      )
    ) {
      return
    }

    event.preventDefault()

    this.dragging = true

    this.canvasTarget.classList.add(
      "is-dragging"
    )

    this.canvasTarget.setPointerCapture(
      event.pointerId
    )

    this.setPosition(event)
  }

  movePosition(event) {
    if (!this.dragging) return

    this.setPosition(event)
  }

  endPosition(event) {
    this.dragging = false

    this.canvasTarget.classList.remove(
      "is-dragging"
    )

    if (
      this.canvasTarget.hasPointerCapture(
        event.pointerId
      )
    ) {
      this.canvasTarget.releasePointerCapture(
        event.pointerId
      )
    }
  }

  setPosition(event) {
    const rect =
      this.canvasTarget.getBoundingClientRect()

    const x =
      ((event.clientX - rect.left) / rect.width) * 100

    const y =
      ((event.clientY - rect.top) / rect.height) * 100

    this.xTarget.value =
      Math.round(
        this.clamp(x, 0, 100)
      )

    this.yTarget.value =
      Math.round(
        this.clamp(y, 0, 100)
      )

    this.update()
  }

  zoomIn() {
    this.changeZoom(0.1)
  }

  zoomOut() {
    this.changeZoom(-0.1)
  }

  changeZoom(change) {
    const current =
      Number(
        this.zoomTarget.value || 1
      )

    const next =
      this.clamp(
        current + change,
        1,
        3
      )

    this.zoomTarget.value =
      next.toFixed(1)

    this.update()
  }

  overlayUp() {
    this.changeOverlay(5)
  }

  overlayDown() {
    this.changeOverlay(-5)
  }

  changeOverlay(change) {
    if (!this.hasOverlayTarget) return

    const current =
      Number(
        this.overlayTarget.value || 0
      )

    const next =
      Math.round(
        this.clamp(
          current + change,
          0,
          90
        )
      )

    this.overlayTarget.value =
      next

    this.update()
  }

  setOverlay(event) {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.value =
      Number(
        event.currentTarget.dataset.overlay
      )

    this.update()
  }

  setBannerLayout(event) {
    if (!this.hasBannerLayoutTarget) return

    const layout =
      event.currentTarget.dataset.layout

    if (!layout) return

    this.bannerLayoutTarget.value =
      layout

    this.updateBannerButtons()
    this.updateRealBannerLayout(layout)
  }

  updateBannerButtons() {
    if (!this.hasBannerLayoutTarget) return

    const current =
      this.bannerLayoutTarget.value ||
      "top"

    this.bannerLayoutButtonTargets.forEach(
      (button) => {
        button.classList.toggle(
          "is-active",
          button.dataset.layout === current
        )
      }
    )
  }

  updateRealBannerLayout(layout) {
    const frame =
      this.findSectionFrame()

    if (!frame) return

    frame.classList.remove(
      "section-frame--top",
      "section-frame--background",
      "section-frame--bottom"
    )

    frame.classList.add(
      `section-frame--${layout}`
    )
  }

  findSectionFrame() {
    if (!this.hasSectionIdValue) return null

    const selector =
      `[data-section-frame-id="${this.sectionIdValue}"]`

    const current =
      document.querySelector(selector)

    if (current) return current

    for (
      const iframe of document.querySelectorAll("iframe")
    ) {
      try {
        const frame =
          iframe.contentDocument?.querySelector(
            selector
          )

        if (frame) return frame
      } catch (_error) {
      }
    }

    try {
      if (window.parent !== window) {
        const parent =
          window.parent.document.querySelector(
            selector
          )

        if (parent) return parent

        for (
          const iframe of window.parent.document.querySelectorAll(
            "iframe"
          )
        ) {
          try {
            const frame =
              iframe.contentDocument?.querySelector(
                selector
              )

            if (frame) return frame
          } catch (_error) {
          }
        }
      }
    } catch (_error) {
    }

    return null
  }

  reset() {
    this.xTarget.value = 50
    this.yTarget.value = 50
    this.zoomTarget.value = 1

    this.update()
  }

  update() {
    const x =
      Number(
        this.xTarget.value || 50
      )

    const y =
      Number(
        this.yTarget.value || 50
      )

    const zoom =
      Number(
        this.zoomTarget.value || 1
      )

    if (this.hasImageTarget) {
      this.imageTarget.style.objectPosition =
        `${x}% ${y}%`

      this.imageTarget.style.transform =
        `scale(${zoom})`

      this.imageTarget.style.transformOrigin =
        `${x}% ${y}%`
    }

    if (this.hasFocusTarget) {
      this.focusTarget.style.left =
        `${x}%`

      this.focusTarget.style.top =
        `${y}%`
    }

    if (this.hasZoomLabelTarget) {
      this.zoomLabelTarget.textContent =
        `${Math.round(zoom * 100)}%`
    }

    if (this.hasPositionLabelTarget) {
      this.positionLabelTarget.textContent =
        `${Math.round(x)}% × ${Math.round(y)}%`
    }

    if (this.hasOverlayTarget) {
      const overlay =
        Number(
          this.overlayTarget.value || 0
        )

      if (this.hasOverlayLabelTarget) {
        this.overlayLabelTarget.textContent =
          `${overlay}%`
      }

      if (this.hasOverlayVisualTarget) {
        this.overlayVisualTarget.style.background =
          `rgba(23, 35, 31, ${overlay / 100})`
      }
    }
  }

  clamp(value, min, max) {
    return Math.min(
      Math.max(value, min),
      max
    )
  }
}
