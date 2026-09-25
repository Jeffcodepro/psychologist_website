import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["handle"]

  connect() {
    this.positionHandles =
      this.positionHandles.bind(this)

    this.resizeObserver =
      new ResizeObserver(() => {
        this.positionHandles()
      })

    this.resizeObserver.observe(
      this.element
    )

    window.addEventListener(
      "resize",
      this.positionHandles
    )

    window.addEventListener(
      "load",
      this.positionHandles
    )

    requestAnimationFrame(() => {
      this.positionHandles()
    })

    setTimeout(() => {
      this.positionHandles()
    }, 250)

    setTimeout(() => {
      this.positionHandles()
    }, 700)
  }

  disconnect() {
    this.resizeObserver?.disconnect()

    window.removeEventListener(
      "resize",
      this.positionHandles
    )

    window.removeEventListener(
      "load",
      this.positionHandles
    )
  }

  positionHandles() {
    const sections =
      this.element.querySelectorAll(
        ".preview-editable-section"
      )

    sections.forEach((section) => {
      const handles =
        section.querySelectorAll(
          ".preview-field-tab"
        )

      handles.forEach((handle) => {
        const field =
          handle.dataset.field

        if (field === "banner") {
          this.positionBannerHandle(
            section,
            handle
          )

          return
        }

        const target =
          this.findTarget(
            section,
            field
          )

        if (!target) {
          handle.style.display =
            "none"

          return
        }

        handle.style.display =
          "flex"

        this.positionBesideTarget(
          section,
          target,
          handle
        )
      })
    })
  }

  findTarget(section, field) {
    const selectors = {
      title: [
        ".section-heading",
        ".hero-content h1",
        ".hero-section h1",
        ".site-section h2"
      ],

      body: [
        ".section-body",
        ".hero-body"
      ],

      image: [
        ".hero-image",
        ".text-image-media",
        ".section-image"
      ]
    }

    const possibleSelectors =
      selectors[field] || []

    for (
      const selector
      of possibleSelectors
    ) {
      const element =
        section.querySelector(
          selector
        )

      if (element) {
        return element
      }
    }

    return null
  }

  positionBesideTarget(
    section,
    target,
    handle
  ) {
    const sectionRect =
      section.getBoundingClientRect()

    const targetRect =
      target.getBoundingClientRect()

    const handleWidth = 34
    const gap = 9

    let left =
      targetRect.left -
      sectionRect.left -
      handleWidth -
      gap

    let top =
      targetRect.top -
      sectionRect.top +
      4

    /*
     * Se não existir espaço do lado esquerdo,
     * colocamos imediatamente acima do elemento.
     * Assim nunca cobrimos o conteúdo.
     */
    if (left < 6) {
      left =
        Math.max(
          6,
          targetRect.left -
            sectionRect.left
        )

      top =
        Math.max(
          6,
          targetRect.top -
            sectionRect.top -
            42
        )
    }

    handle.style.left =
      `${left}px`

    handle.style.right =
      "auto"

    handle.style.top =
      `${Math.max(6, top)}px`
  }

  positionBannerHandle(
    section,
    handle
  ) {
    handle.style.left =
      "auto"

    handle.style.right =
      "10px"

    handle.style.top =
      "10px"
  }
}
