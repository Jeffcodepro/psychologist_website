import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "iframe",
    "device",
    "deviceButton",
    "languageButton"
  ]

  static values = {
    frameUrl: String
  }

  connect() {
    this.locale = "pt-BR"
    this.device = "desktop"

    this.handleFrameLoad =
      this.handleFrameLoad.bind(this)

    if (this.hasIframeTarget) {
      this.iframeTarget.addEventListener(
        "load",
        this.handleFrameLoad
      )
    }
  }

  disconnect() {
    if (this.hasIframeTarget) {
      this.iframeTarget.removeEventListener(
        "load",
        this.handleFrameLoad
      )
    }
  }

  changeDevice(event) {
    const device =
      event.currentTarget.dataset.device

    if (!device) return

    this.device = device

    this.deviceTarget.classList.remove(
      "admin-preview-device--desktop",
      "admin-preview-device--tablet",
      "admin-preview-device--mobile"
    )

    this.deviceTarget.classList.add(
      `admin-preview-device--${device}`
    )

    this.deviceButtonTargets.forEach((button) => {
      button.classList.toggle(
        "is-active",
        button.dataset.device === device
      )
    })
  }

  changeLanguage(event) {
    const locale =
      event.currentTarget.dataset.locale

    if (!locale) return

    this.locale = locale

    const url =
      this.currentFrameUrl()

    url.searchParams.set(
      "locale",
      locale
    )

    this.iframeTarget.src =
      url.toString()

    this.updateLanguageButtons(locale)
  }

  handleFrameLoad() {
    const url =
      this.currentFrameUrl()

    const locale =
      url.searchParams.get("locale") ||
      "pt-BR"

    this.locale = locale

    this.updateLanguageButtons(locale)
  }

  currentFrameUrl() {
    try {
      const currentUrl =
        this.iframeTarget
          .contentWindow
          .location
          .href

      if (currentUrl) {
        return new URL(currentUrl)
      }
    } catch (_error) {
    }

    if (this.iframeTarget.src) {
      return new URL(
        this.iframeTarget.src,
        window.location.origin
      )
    }

    return new URL(
      this.frameUrlValue,
      window.location.origin
    )
  }

  updateLanguageButtons(locale) {
    this.languageButtonTargets.forEach((button) => {
      button.classList.toggle(
        "is-active",
        button.dataset.locale === locale
      )
    })
  }
}
