import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "iframe",
    "device",
    "deviceButton",
    "languageButton", "status"
  ]

  static values = {
    frameUrl: String, locale: String, languageUrl: String
  }

  connect() {
    this.locale = this.localeValue || "pt-BR"
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

  async changeLanguage(event) {
    const locale = event.currentTarget.dataset.locale
    if (!locale || this.changingLanguage) return
    this.changingLanguage = true
    this.languageButtonTargets.forEach(button => { button.disabled = true })
    try {
      const response = await fetch(this.languageUrlValue, {
        method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || '' },
        body: JSON.stringify({ language: locale })
      })
      if (!response.ok) throw new Error()
      const data = await response.json()
      this.locale = data.language
      const url = this.currentFrameUrl()
      url.searchParams.delete("locale")
      this.iframeTarget.src = url.toString()
      this.updateLanguageButtons(this.locale)
      this.statusTarget.textContent = ""
    } catch (_) {
      this.statusTarget.textContent = "Não foi possível trocar o idioma. Tente novamente."
    } finally {
      this.changingLanguage = false
      this.languageButtonTargets.forEach(button => { button.disabled = false })
    }
  }

  handleFrameLoad() {
    this.syncEditingDevice()
    try {
      const language = this.iframeTarget.contentDocument.documentElement.lang
      if (["pt-BR", "en"].includes(language)) this.locale = language
    } catch (_) { }
    this.updateLanguageButtons(this.locale)
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
