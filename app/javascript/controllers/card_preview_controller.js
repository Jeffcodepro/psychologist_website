import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "canvas", "size"]
  static values = { scope: String, locale: String }

  connect() {
    this.form = this.element.closest("form")
    this.card = this.canvasTarget.querySelector(".compact-card")
    this.initialLinked = Boolean(this.card.querySelector("[data-preview-destination]:not([hidden])"))
    this.linkedBodies = JSON.parse(this.previewTarget.dataset.linkedBodies)
    this.onInput = (event) => {
      if (event.target.name === "card_section") this.sectionChanged()
      const device = event.target.name?.match(/\[card_settings\]\[(desktop|tablet|mobile)\]/)?.[1]
      if (device) this.setDevice(device)
      this.render()
    }
    this.form.addEventListener("input", this.onInput)
    this.form.addEventListener("change", this.onInput)
    this.observer = new ResizeObserver(() => this.updateSize())
    this.observer.observe(this.card)
    this.render()
  }

  disconnect() {
    this.form?.removeEventListener("input", this.onInput)
    this.form?.removeEventListener("change", this.onInput)
    this.observer?.disconnect()
  }

  field(name) { return this.form.elements.namedItem(`${this.scopeValue}[${name}]`) }
  value(name) { return this.field(name)?.value || "" }
  localized(name) { return (this.localeValue === "en" && this.value(`${name}_en`)) || this.value(name) }

  render() {
    if (!this.card) return
    const title = this.localized("title")
    const linkedId = this.field("linked_page_id")?.value || this.previewTarget.dataset.linkedPageId
    const body = this.localized("body") || (this.linked() ? this.linkedBodies[linkedId]?.[this.localeValue] : "") || ""
    // Match Rails' plain-text teaser; never interpret input as live HTML.
    const plain = body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
    const limit = this.linked() ? 240 : 360
    let summary = plain
    if (plain.length > limit) {
      summary = plain.slice(0, limit - 3)
      const boundary = summary.lastIndexOf(" ")
      if (boundary > 0) summary = summary.slice(0, boundary)
      summary += "..."
    }
    this.card.querySelector(".compact-card__title").textContent = title
    this.card.querySelector(".compact-card__summary").textContent = summary
    this.card.dataset.cardReaderTruncatedValue = summary !== plain
    const dialog = this.card.querySelector("dialog")
    dialog.setAttribute("aria-label", title)
    dialog.querySelector("h2").textContent = title
    dialog.querySelector(".card-reader-dialog__body").textContent = body.replace(/<[^>]*>/g, "")
    const destination = this.card.querySelector("[data-preview-destination]")
    destination.hidden = !this.linked()
    this.card.classList.toggle("compact-card--linked", this.linked())
    for (const device of ["desktop", "tablet", "mobile"]) {
      for (const [field, attribute, fallback] of [["image_layout", "Layout", "top"], ["button_position", "Button", "bottom"], ["button_alignment", "Align", "left"]]) {
        const setting = this.value(`card_settings][${device}][${field}`) || this.value(`card_settings][desktop][${field}`) || fallback
        this.card.dataset[`card${attribute}${device[0].toUpperCase() + device.slice(1)}`] = setting
      }
    }
    for (const device of ["desktop", "tablet", "mobile"]) {
      for (const [field, fallback] of [["overlay_color", "#0c1b15"], ["background_text_color", "#ffffff"], ["overlay_opacity", "68"]]) {
        const raw = this.value(`card_settings][${device}][${field}`) || this.value(`card_settings][desktop][${field}`) || fallback
        const value = field === "overlay_opacity" ? Math.max(0, Math.min(100, Number(raw) || 0)) / 100 : (/^#[0-9a-f]{6}$/i.test(raw) ? raw : fallback)
        this.card.style.setProperty(`--card-${device}-${field.replaceAll("_", "-")}`, value)
      }
    }
    for (const device of ["desktop", "tablet", "mobile"]) {
      for (const field of ["text_padding", "title_body_gap", "image_text_gap", "button_gap"]) {
        const raw = this.value(`card_settings][${device}][${field}`) || this.value(`card_settings][desktop][${field}`)
        const property = `--card-${device}-${field.replaceAll("_", "-")}`
        if (raw === "") this.card.style.removeProperty(property)
        else this.card.style.setProperty(property, `${Math.max(0, Math.min(40, Number(raw) || 0))}px`)
      }
    }
    const image = this.card.querySelector(".compact-card__image")
    const removing = this.form.querySelector(`[name="${this.scopeValue}[remove_image]"][type="checkbox"]`)?.checked
    const source = this.element.closest(".media-input")?.querySelector("[data-media-source-target=source]")?.value
    const hasImage = source && source !== "image" ? Boolean(this.card.querySelector(".cms-video")) : Boolean(image.getAttribute("src")) && !removing
    this.card.querySelector(".compact-card__media").hidden = !hasImage
    this.card.classList.toggle("compact-card--with-image", hasImage)
    image.alt = title
    const currentDevice = this.previewTarget.dataset.device
    this.card.dataset.editorBackground = hasImage && this.card.dataset[`cardLayout${currentDevice[0].toUpperCase() + currentDevice.slice(1)}`] === "background"
    this.card.dispatchEvent(new CustomEvent("card-preview:refresh"))
  }

  linked() {
    const field = this.field("linked_page_id")
    return field ? Boolean(field.value) : this.initialLinked
  }

  sectionChanged() {
    const styles = JSON.parse(this.previewTarget.dataset.sectionStyles)
    this.canvasTarget.setAttribute("style", styles[this.form.elements.namedItem("card_section").value] || this.previewTarget.dataset.defaultStyle)
  }

  deviceChanged(event) { this.setDevice(event.currentTarget.dataset.device); this.render() }
  setDevice(device) {
    this.previewTarget.dataset.device = device
    this.previewTarget.querySelectorAll("button[data-device]").forEach(button => button.setAttribute("aria-pressed", button.dataset.device === device))
  }
  widthChanged(event) { this.previewTarget.style.setProperty("--preview-card-width", `${event.currentTarget.value}px`) }
  updateSize() {
    const { width, height } = this.card.getBoundingClientRect()
    this.sizeTarget.textContent = `${Math.round(width)} × ${Math.round(height)} px · tamanho real da prévia`
  }
}
