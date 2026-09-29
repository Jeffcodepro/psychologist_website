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
    this.locale = new URL(this.iframeTarget.src).searchParams.get("locale") || "pt-BR"
    this.device = "desktop"
    this.updateLanguageButtons(this.locale)

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
    this.syncEditingDevice()
  }

  changeLanguage(event) {
    const locale =
      event.currentTarget.dataset.locale

    if (!locale) return

    this.locale = locale
    const parentUrl = new URL(window.location.href)
    parentUrl.searchParams.set("locale", locale)
    history.replaceState({}, "", parentUrl)
    document.querySelectorAll('a[href]').forEach(link => {
      const target = new URL(link.href, location.origin)
      if (target.origin === location.origin && target.pathname.startsWith('/admin')) {
        target.searchParams.set('locale', locale)
        link.href = target.toString()
      }
    })

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
    this.syncEditingDevice()
    const url =
      this.currentFrameUrl()

    const locale =
      url.searchParams.get("locale") ||
      "pt-BR"

    this.locale = locale

    this.updateLanguageButtons(locale)
  }

  syncEditingDevice() {
    try {
      this.iframeTarget.contentDocument.documentElement.dataset.editingDevice = this.device
      this.iframeTarget.contentDocument.dispatchEvent(new CustomEvent("cms:editing-device"))
    } catch (_error) {
    }
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
