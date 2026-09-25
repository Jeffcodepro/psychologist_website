import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.add(
      "admin-page--entering"
    )

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.classList.remove(
          "admin-page--entering"
        )

        this.element.classList.add(
          "admin-page--ready"
        )
      })
    })

    this.beforeVisit =
      this.beforeVisit.bind(this)

    document.addEventListener(
      "turbo:before-visit",
      this.beforeVisit
    )
  }

  disconnect() {
    document.removeEventListener(
      "turbo:before-visit",
      this.beforeVisit
    )
  }

  beforeVisit() {
    this.element.classList.add(
      "admin-page--leaving"
    )
  }
}
