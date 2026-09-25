import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const activeTab =
      this.tabTargets.find((tab) =>
        tab.classList.contains("is-active")
      ) || this.tabTargets[0]

    if (activeTab) {
      this.activate(activeTab.dataset.tab, false)
    }
  }

  select(event) {
    const tab = event.currentTarget.dataset.tab

    if (!tab) return

    this.activate(tab, true)
  }

  activate(name, animate = true) {
    this.tabTargets.forEach((tab) => {
      tab.classList.toggle(
        "is-active",
        tab.dataset.tab === name
      )
    })

    this.panelTargets.forEach((panel) => {
      const active =
        panel.dataset.panel === name

      if (active) {
        panel.hidden = false

        if (animate) {
          panel.classList.remove("is-active")

          requestAnimationFrame(() => {
            panel.classList.add("is-active")
          })
        } else {
          panel.classList.add("is-active")
        }
      } else {
        panel.hidden = true
        panel.classList.remove("is-active")
      }
    })
  }
}
