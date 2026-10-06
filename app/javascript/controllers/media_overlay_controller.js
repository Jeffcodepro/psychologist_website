import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { role: String }

  connect() { this.refresh() }

  refresh() {
    const panels = [...this.element.querySelectorAll("[data-device-appearance-target='panel']")]
    const base = panels.find(panel => panel.dataset.device === "desktop")
    const value = (panel, property) => {
      const field = panel.querySelector(`[data-overlay-property='${property}']`)
      const baseField = base.querySelector(`[data-overlay-property='${property}']`)
      return field.value || (panel !== base && baseField.value) || field.dataset.overlayDefault
    }
    panels.forEach(panel => {
      const color = value(panel, "color")
      const opacity = Number(value(panel, "opacity")) / 100
      const sample = panel.querySelector("[data-overlay-sample]")
      for (const [property, effective] of [["color", color], ["opacity", opacity * 100]]) {
        const field = panel.querySelector(`[data-overlay-property='${property}']`)
        const picker = field.closest('[data-controller~="paired-input"]').querySelector('[data-paired-input-target="picker"]')
        if (property !== "color" || /^#[0-9a-f]{6}$/i.test(effective)) picker.value = effective
      }
      if (/^#[0-9a-f]{6}$/i.test(color)) sample.style.setProperty("--overlay-sample-color", color)
      if (Number.isFinite(opacity) && opacity >= 0 && opacity <= 1) sample.style.setProperty("--overlay-sample-opacity", opacity)
    })
  }
}
