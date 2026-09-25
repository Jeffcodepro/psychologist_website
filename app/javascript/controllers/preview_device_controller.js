import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "frame",
    "button",
    "iframe"
  ]

  connect() {
    const savedDevice =
      localStorage.getItem(
        "psychologist-preview-device"
      )

    const device =
      savedDevice || "desktop"

    this.setDevice(device)
  }

  change(event) {
    const device =
      event.currentTarget
        .dataset
        .device

    this.setDevice(device)

    localStorage.setItem(
      "psychologist-preview-device",
      device
    )
  }

  setDevice(device) {
    this.frameTarget.classList.remove(
      "preview-device-frame--desktop",
      "preview-device-frame--tablet",
      "preview-device-frame--mobile"
    )

    this.frameTarget.classList.add(
      `preview-device-frame--${device}`
    )

    this.buttonTargets.forEach(
      (button) => {
        button.classList.toggle(
          "is-active",
          button.dataset.device === device
        )
      }
    )
  }
}
