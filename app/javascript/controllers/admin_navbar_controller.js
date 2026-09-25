import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "button",
    "menu"
  ]


  connect() {
    this.close()
  }


  toggle() {
    if (
      this.menuTarget.hidden
    ) {
      this.open()
    } else {
      this.close()
    }
  }


  open() {
    this.menuTarget.hidden =
      false

    this.buttonTarget.setAttribute(
      "aria-expanded",
      "true"
    )

    this.element.classList.add(
      "is-menu-open"
    )
  }


  close() {
    if (
      this.hasMenuTarget
    ) {
      this.menuTarget.hidden =
        true
    }

    if (
      this.hasButtonTarget
    ) {
      this.buttonTarget.setAttribute(
        "aria-expanded",
        "false"
      )
    }

    this.element.classList.remove(
      "is-menu-open"
    )
  }
}
