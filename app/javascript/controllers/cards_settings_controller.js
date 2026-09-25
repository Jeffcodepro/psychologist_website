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

    "preview", "deviceButton", "deviceLabel"
  ]

  static values = {
    sectionId: Number
  }


  connect() {
    this.previewDevice = "desktop"
    this.refresh()
  }


  chooseDevice(event) {
    this.previewDevice = event.currentTarget.dataset.device
    this.deviceButtonTargets.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.device === this.previewDevice)))
    this.deviceLabelTarget.textContent = { desktop: "Desktop", tablet: "Tablet", mobile: "Mobile" }[this.previewDevice]
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
        !horizontal || carousel
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


    const columns = carousel ? ({ desktop: 3, tablet: 2, mobile: 1 }[this.previewDevice || "desktop"]) : { desktop: this.desktopValue(), tablet: this.tabletValue(), mobile: this.mobileValue() }[this.previewDevice || "desktop"]

    preview.style.setProperty(
      "--cards-preview-columns",
      columns
    )
  }


  updateRealPreview(orientation) {
    const section = this.findCardsSection()
    if (!section) return
    section.classList.remove("card-collection--horizontal", "card-collection--vertical")
    section.classList.add(`card-collection--${orientation}`)
    section.style.setProperty("--cards-desktop", this.desktopValue())
    section.style.setProperty("--cards-tablet", this.tabletValue())
    section.style.setProperty("--cards-mobile", this.mobileValue())
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
      ".card-collection"
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
