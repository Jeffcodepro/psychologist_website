import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "button",
    "menu",
    "backdrop"
  ]


  connect() {
    this.handleKeydown =
      this.handleKeydown.bind(this)

    this.handleResize =
      this.handleResize.bind(this)


    document.addEventListener(
      "keydown",
      this.handleKeydown
    )


    window.addEventListener(
      "resize",
      this.handleResize
    )
  }


  disconnect() {
    document.removeEventListener(
      "keydown",
      this.handleKeydown
    )


    window.removeEventListener(
      "resize",
      this.handleResize
    )
  }


  toggle() {
    if (
      this.hasMenuTarget &&
      this.menuTarget.hidden
    ) {
      this.open()
    } else {
      this.close()
    }
  }


  open() {
    if (this.hasMenuTarget) {
      this.menuTarget.hidden =
        false
    }


    if (this.hasBackdropTarget) {
      this.backdropTarget.hidden =
        false
    }


    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute(
        "aria-expanded",
        "true"
      )
    }


    this.element.classList.add(
      "is-open"
    )


    document.body.classList.add(
      "site-navigation-open"
    )
  }


  close() {
    if (this.hasMenuTarget) {
      this.menuTarget.hidden =
        true
    }


    if (this.hasBackdropTarget) {
      this.backdropTarget.hidden =
        true
    }


    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute(
        "aria-expanded",
        "false"
      )
    }


    this.element.classList.remove(
      "is-open"
    )


    document.body.classList.remove(
      "site-navigation-open"
    )
  }


  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }


  handleResize() {
    if (
      window.innerWidth > 960
    ) {
      this.close()
    }
  }
}
