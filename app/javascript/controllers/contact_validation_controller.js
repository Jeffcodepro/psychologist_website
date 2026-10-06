import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = { language: String }

  connect() {
    this.phoneReady = import("libphonenumber").then(() => {
      if (!this.element.isConnected) return
      this.fieldTargets.filter(field => field.type === "tel" && field.value).forEach(field => { this.detectCountry(field); this.validate(field, false) })
    }).catch(() => { /* The server still validates every submission. */ })
    this.fieldTargets.forEach(field => this.validate(field, false))
  }

  get english() { return this.languageValue === "en" }
  message(kind) {
    return {
      name: this.english ? "Enter at least a first and last name, without numbers." : "Informe pelo menos nome e sobrenome, sem números.",
      email: this.english ? "Enter a valid email address, such as name@example.com." : "Informe um e-mail válido, como nome@exemplo.com.",
      tel: this.english ? "Enter a valid phone number for the selected country, including an area code when needed." : "Informe um telefone válido para o país selecionado, incluindo o código de área quando necessário.",
      required: this.english ? "Please fill out this field." : "Preencha este campo."
    }[kind]
  }

  countrySelect(field) { return field.closest("[data-phone-group]")?.querySelector("[data-phone-country]") }

  parsePhone(field) {
    if (!window.libphonenumber || !/^\+?[0-9 ().-]+$/.test(field.value.trim())) return null
    try {
      return window.libphonenumber.parsePhoneNumberFromString(field.value.trim(), { defaultCountry: this.countrySelect(field)?.value || "BR", extract: false })
    } catch { return null }
  }

  detectCountry(field) {
    if (!field.value.trim().startsWith("+")) return
    const parsed = this.parsePhone(field)
    const country = this.countrySelect(field)
    if (!parsed?.isValid() || !parsed.country || !country) return
    if (country.tomselect) country.tomselect.setValue(parsed.country, true)
    else country.value = parsed.country
  }

  input(event) {
    const field = event.target
    if (field.type === "tel") this.detectCountry(field)
    this.validate(field, field.dataset.touched === "true")
  }
  blur(event) { event.target.dataset.touched = "true"; this.validate(event.target, true) }
  change(event) { this.validate(event.target, event.target.dataset.touched === "true") }
  countryChanged(event) {
    const field = event.target.closest("[data-phone-group]")?.querySelector('input[type="tel"]')
    if (field) this.validate(field, field.dataset.touched === "true")
  }

  validate(field, show) {
    const value = field.value.trim()
    const kind = field.dataset.validationKind
    let message = ""
    if (field.required && (!value || (field.type === "checkbox" && !field.checked))) message = this.message("required")
    else if (value) {
      if (kind === "name") {
        const parts = value.normalize("NFC").split(/\s+/)
        if (parts.length < 2 || !parts.every(part => /^\p{L}[\p{L}\p{M}]*(?:['’\-][\p{L}\p{M}]+)*$/u.test(part))) message = this.message("name")
      } else if (kind === "email") {
        const [local, domain, extra] = value.split("@")
        const labels = domain?.split(".") || []
        if (extra !== undefined || !local || local.length > 64 || value.length > 254 ||
            !/^[A-Za-z0-9.!#$%&'*+\/?^_`{|}~=\-]+$/.test(local) || local.startsWith(".") || local.endsWith(".") || local.includes("..") ||
            labels.length < 2 || !labels.every(label => /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label)) || !/^[a-z]{2,63}$/i.test(labels.at(-1))) message = this.message("email")
      } else if (kind === "tel" && window.libphonenumber) {
        const parsed = this.parsePhone(field)
        if (value.length > 32 || !parsed?.isValid() || parsed.ext || parsed.country !== this.countrySelect(field)?.value) message = this.message("tel")
      }
    }
    field.setCustomValidity(message)
    if (show) {
      field.setAttribute("aria-invalid", message ? "true" : "false")
      const error = field.closest(".appointment-form__field")?.querySelector("[data-field-error]")
      if (error) { error.textContent = message; error.hidden = !message }
    }
    return !message
  }

  submit(event) {
    let invalid = null
    this.fieldTargets.forEach(field => { if (!this.validate(field, true) && !invalid) invalid = field })
    if (invalid) { event.preventDefault(); event.stopImmediatePropagation(); invalid.focus(); invalid.reportValidity() }
  }
}
