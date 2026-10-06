import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "imagePreview",
    "compositionPreview"
  ]

  connect() {
    this.updateEditorPreviews(this.selectedValue("image_shape") || "rounded", this.selectedValue("media_layout") || "text_left", this.selectedValue("media_size") || "medium")
  }

  refresh() {
    const shape =
      this.selectedValue("image_shape") ||
      "rounded"

    const layout =
      this.selectedValue("media_layout") ||
      "text_left"

    const size =
      this.selectedValue("media_size") ||
      "medium"

    this.updateEditorPreviews(
      shape,
      layout,
      size
    )

    this.updateRealPreview(
      shape,
      layout,
      size
    )
  }

  refreshColors() {
    const frame =
      this.findRealFrame()

    if (!frame) return

    const fields = {
      title: "--section-title-color",
      body: "--section-body-color",
      accent: "--section-accent-color",
      background: "--section-background-color",
      overlay: "--section-overlay-color"
    }

    Object.entries(fields).forEach(
      ([role, cssVariable]) => {
        const input =
          this.element.querySelector(
            `[data-color-role="${role}"]`
          )

        if (!input) return

        frame.style.setProperty(
          cssVariable.replace("--section-", "--desktop-"),
          input.value
        )

        const display =
          input
            .closest(
              ".section-color-control"
            )
            ?.querySelector("strong")

        if (display) {
          display.textContent =
            input.value.toUpperCase()
        }
      }
    )
  }

  updateEditorPreviews(
    shape,
    layout,
    size
  ) {
    this.imagePreviewTargets.forEach(
      (preview) => {
        this.removeClassesWithPrefix(
          preview,
          "admin-media-canvas--shape-"
        )

        preview.classList.add(
          `admin-media-canvas--shape-${shape}`
        )
      }
    )

    this.compositionPreviewTargets.forEach(
      (preview) => {
        this.removeClassesWithPrefix(
          preview,
          "is-layout-"
        )

        this.removeClassesWithPrefix(
          preview,
          "is-size-"
        )

        this.removeClassesWithPrefix(
          preview,
          "is-shape-"
        )

        preview.classList.add(
          `is-layout-${layout}`
        )

        preview.classList.add(
          `is-size-${size}`
        )

        preview.classList.add(
          `is-shape-${shape}`
        )
      }
    )
  }

  updateRealPreview(
    shape,
    layout,
    size
  ) {
    const frame =
      this.findRealFrame()

    if (!frame) return
    frame.dataset.layoutDesktop = layout
    const radius = { rectangle: "0px", rounded: "24px", square: "4px", circle: "50%", oval: "50%", arch: "50% 50% 16px 16px", cutout: "0px" }[shape]
    frame.style.setProperty("--desktop-image-radius", radius)
    frame.style.setProperty("--desktop-image-overflow", shape === "cutout" ? "visible" : "hidden")
    frame.style.setProperty("--desktop-image-tint-display", shape === "cutout" ? "none" : "block")
    frame.style.setProperty("--desktop-image-ratio", ["square", "circle"].includes(shape) ? "1 / 1" : "4 / 5")
    frame.style.setProperty("--desktop-image-width", { small: "250px", medium: "350px", large: "460px" }[size])
    frame.style.setProperty("--desktop-layout-columns", !["text_left", "text_right"].includes(layout) ? "minmax(0, 1fr)" : "minmax(0, 1.15fr) minmax(0, 0.85fr)")
    frame.style.setProperty("--desktop-copy-order", ["text_right", "media_top"].includes(layout) ? 2 : 1)
    frame.style.setProperty("--desktop-media-order", ["text_right", "media_top"].includes(layout) ? 1 : 2)

    const section =
      frame.querySelector(
        ".hero-section, .text-image-section"
      )

    if (!section) return

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
      `${prefix}--media_bottom`,
      `${prefix}--media-small`,
      `${prefix}--media-medium`,
      `${prefix}--media-large`
    )

    section.classList.add(
      `${prefix}--${layout}`
    )

    section.classList.add(
      `${prefix}--media-${size}`
    )

    const heroImage =
      section.querySelector(
        ".hero-section__profile-frame"
      )

    if (heroImage) {
      this.removeClassesWithPrefix(
        heroImage,
        "hero-section__profile-frame--"
      )

      heroImage.classList.add(
        `hero-section__profile-frame--${shape}`
      )
    }

    const textImage =
      section.querySelector(
        ".text-image-section__media-frame"
      )

    if (textImage) {
      this.removeClassesWithPrefix(
        textImage,
        "text-image-section__media-frame--"
      )

      textImage.classList.add(
        `text-image-section__media-frame--${shape}`
      )
    }
  }

  findRealFrame() {
    const sectionId =
      this.sectionId()

    if (!sectionId) return null

    const selector =
      `[data-section-frame-id="${sectionId}"]`

    const current =
      document.querySelector(selector)

    if (current) return current

    for (
      const iframe of document.querySelectorAll(
        "iframe"
      )
    ) {
      try {
        const result =
          iframe.contentDocument?.querySelector(
            selector
          )

        if (result) return result
      } catch (_error) {
      }
    }

    try {
      if (window.parent !== window) {
        const parentResult =
          window.parent.document.querySelector(
            selector
          )

        if (parentResult) {
          return parentResult
        }

        for (
          const iframe of window.parent.document.querySelectorAll(
            "iframe"
          )
        ) {
          try {
            const result =
              iframe.contentDocument?.querySelector(
                selector
              )

            if (result) return result
          } catch (_error) {
          }
        }
      }
    } catch (_error) {
    }

    return null
  }

  sectionId() {
    const form =
      this.element.querySelector("form")

    if (!form) return null

    const match =
      form.action.match(
        /\/sections\/(\d+)/
      )

    return match?.[1]
  }

  selectedValue(field) {
    const input =
      this.element.querySelector(
        `input[name="section[${field}]"]:checked`
      )

    return input?.value
  }

  removeClassesWithPrefix(
    element,
    prefix
  ) {
    Array
      .from(element.classList)
      .filter(
        (className) =>
          className.startsWith(prefix)
      )
      .forEach(
        (className) =>
          element.classList.remove(
            className
          )
      )
  }
}
