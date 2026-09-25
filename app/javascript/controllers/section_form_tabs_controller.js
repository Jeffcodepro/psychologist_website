import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const active =
      this.tabTargets.find((tab) =>
        tab.classList.contains("is-active")
      ) || this.tabTargets[0]

    if (active) {
      this.activate(active.dataset.tab)
    }
  }

  select(event) {
    this.activate(event.currentTarget.dataset.tab)
  }

  activate(name) {
    this.tabTargets.forEach((tab) => {
      tab.classList.toggle(
        "is-active",
        tab.dataset.tab === name
      )
    })

    this.panelTargets.forEach((panel) => {
      const active =
        panel.dataset.panel === name

      panel.hidden = !active
      panel.classList.toggle("is-active", active)
    })
  }
}
