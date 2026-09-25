import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "orientationValue",
    "horizontalOption",
    "verticalOption",

    "wrap",
    "wrapGroup",

    "columnsGroup",
    "columnsDescription",

    "desktopColumns",
    "tabletColumns",
    "mobileColumns",

    "carouselGroup",
    "carouselMessage",

    "preview"
  ]

  static values = {
    sectionId: Number
  }


  connect() {
    this.refresh()
  }


  selectHorizontal() {
    this.orientationValueTarget.value =
      "horizontal"

    this.refresh()
  }


  selectVertical() {
    this.orientationValueTarget.value =
      "vertical"

    this.refresh()
  }


  currentOrientation() {
    return (
      this.orientationValueTarget.value ||
      "horizontal"
    )
  }


  refresh() {
    const orientation =
      this.currentOrientation()

    const horizontal =
      orientation === "horizontal"

    const wrap =
      this.hasWrapTarget ?
        this.wrapTarget.checked :
        true

    const carousel =
      horizontal && !wrap


    this.updateSelection(
      orientation
    )

    this.updateControls(
      horizontal,
      carousel
    )

    this.updateMiniPreview(
      orientation,
      carousel
    )

    this.updateRealPreview(
      orientation
    )
  }


  updateSelection(orientation) {
    if (this.hasHorizontalOptionTarget) {
      this.horizontalOptionTarget
        .classList
        .toggle(
          "is-selected",
          orientation === "horizontal"
        )
    }


    if (this.hasVerticalOptionTarget) {
      this.verticalOptionTarget
        .classList
        .toggle(
          "is-selected",
          orientation === "vertical"
        )
    }
  }


  updateControls(
    horizontal,
    carousel
  ) {
    if (this.hasWrapGroupTarget) {
      this.wrapGroupTarget.hidden =
        !horizontal
    }


    if (this.hasColumnsGroupTarget) {
      this.columnsGroupTarget.hidden =
        !horizontal
    }


    if (this.hasCarouselGroupTarget) {
      this.carouselGroupTarget.hidden =
        !carousel
    }


    if (this.hasCarouselMessageTarget) {
      this.carouselMessageTarget.hidden =
        !carousel
    }


    if (
      this.hasColumnsDescriptionTarget
    ) {
      this.columnsDescriptionTarget.textContent =
        carousel ?
          "Quantos cards ficam visíveis ao mesmo tempo." :
          "Quantos cards aparecem em cada linha."
    }
  }


  updateMiniPreview(
    orientation,
    carousel
  ) {
    if (!this.hasPreviewTarget) {
      return
    }

    const preview =
      this.previewTarget


    preview.classList.remove(
      "is-horizontal",
      "is-vertical",
      "is-carousel"
    )


    preview.classList.add(
      orientation === "vertical" ?
        "is-vertical" :
        "is-horizontal"
    )


    preview.classList.toggle(
      "is-carousel",
      carousel
    )


    const columns =
      this.hasDesktopColumnsTarget ?
        Number(
          this.desktopColumnsTarget.value
        ) :
        3


    preview.style.setProperty(
      "--cards-preview-columns",
      columns
    )
  }


  updateRealPreview(orientation) {
    const section =
      this.findCardsSection()

    if (!section) {
      return
    }


    section.classList.remove(
      "cards-section--horizontal",
      "cards-section--vertical"
    )


    section.classList.add(
      `cards-section--${orientation}`
    )


    this.updateColumnClass(
      section,
      "desktop",
      this.desktopValue()
    )


    this.updateColumnClass(
      section,
      "tablet",
      this.tabletValue()
    )


    this.updateColumnClass(
      section,
      "mobile",
      this.mobileValue()
    )


    const grid =
      section.querySelector(
        ".cards-section__grid"
      )

    const list =
      section.querySelector(
        ".cards-section__list"
      )


    if (
      orientation === "vertical" &&
      grid
    ) {
      grid.classList.remove(
        "cards-section__grid"
      )

      grid.classList.add(
        "cards-section__list"
      )
    }


    if (
      orientation === "horizontal" &&
      list
    ) {
      list.classList.remove(
        "cards-section__list"
      )

      list.classList.add(
        "cards-section__grid"
      )
    }
  }


  findCardsSection() {
    if (!this.hasSectionIdValue) {
      return null
    }

    const wrapper =
      document.querySelector(
        `.preview-editable-section[data-section-id="${this.sectionIdValue}"]`
      )

    if (!wrapper) {
      return null
    }

    return wrapper.querySelector(
      ".cards-section"
    )
  }


  desktopValue() {
    return this.hasDesktopColumnsTarget ?
      Number(
        this.desktopColumnsTarget.value
      ) :
      3
  }


  tabletValue() {
    return this.hasTabletColumnsTarget ?
      Number(
        this.tabletColumnsTarget.value
      ) :
      2
  }


  mobileValue() {
    return this.hasMobileColumnsTarget ?
      Number(
        this.mobileColumnsTarget.value
      ) :
      1
  }


  updateColumnClass(
    element,
    breakpoint,
    value
  ) {
    const prefix =
      `cards-section--${breakpoint}-`

    const oldClasses =
      Array
        .from(element.classList)
        .filter(
          (className) =>
            className.startsWith(prefix)
        )


    oldClasses.forEach(
      (className) =>
        element.classList.remove(
          className
        )
    )


    element.classList.add(
      `${prefix}${value}`
    )
  }
}
