import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "image", "empty", "file", "dimensions", "shape", "x", "y", "zoom", "xField", "yField", "zoomField", "xLabel", "yLabel", "zoomLabel", "positionHint", "error", "adjustment", "shadowLabel", "backgroundButton", "backgroundStatus"]
  static values = { cardPreview: Boolean, shape: String, baseShape: String, shapeField: String, kind: String, adjustments: Object, x: Number, y: Number, zoom: Number, originalUrl: String, cutoutUrl: String }

  connect() {
    this.form = this.element.closest("form")
    this.onFormChange = (event) => {
      if (event.target.name?.includes("[media_adjustments]")) {
        this.render()
        if (!this.hasBackgroundButtonTarget && event.target.name.endsWith("[remove_background]")) {
          this.imageTarget.src = this.adjustment("remove_background", 0) === 1 && this.cutoutUrlValue ? this.cutoutUrlValue : this.originalUrlValue
        }
      }
      if (this.kindValue === "banner") return
      if (event.target.name === this.shapeFieldValue) {
        this.shapeValue = event.target.value || this.baseShapeValue
        this.render()
      }
    }
    this.onSubmit = event => {
      if (!this.processing) return
      event.preventDefault()
      this.backgroundStatusTarget.textContent = "Aguarde a prévia do recorte terminar antes de salvar."
    }
    this.form?.addEventListener("submit", this.onSubmit)
    this.form?.addEventListener("change", this.onFormChange)
    this.form?.addEventListener("input", this.onFormChange)
    this.render()
    if (this.imageTarget.complete && this.imageTarget.naturalWidth) this.loaded()
    if (this.adjustment("remove_background", 0) === 1 && this.cutoutUrlValue) this.loadBackground()
  }

  disconnect() {
    this.cancelBackground()
    this.form?.removeEventListener("submit", this.onSubmit)
    this.form?.removeEventListener("change", this.onFormChange)
    this.form?.removeEventListener("input", this.onFormChange)
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  choose() { this.fileTarget.click() }

  setting(key, fallback) {
    const own = this.adjustmentTargets.find(input => input.dataset.adjustment === key)
    // Responsive crop panels share effects with the primary image, while retaining their own zoom.
    const media = this.kindValue === "banner" ? "banner" : "image"
    const base = this.form?.elements.namedItem(`section[media_adjustments][${media}][${key}]`)
    return own?.value ?? base?.value ?? this.adjustmentsValue[key] ?? fallback
  }

  adjustment(key, fallback) { return Number(this.setting(key, fallback)) }

  setAdjustment(key, value) {
    const field = this.adjustmentTargets.find(input => input.dataset.adjustment === key)
    if (field) {
      if (field.tomselect) field.tomselect.setValue(value, true)
      else field.value = value
      field.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  cutoutPreset() {
    const field = this.form?.querySelector(`[name="${this.shapeFieldValue}"][value="cutout"]`) || this.form?.elements.namedItem(this.shapeFieldValue)
    if (field) {
      if (field.type === "radio") field.checked = true
      else if (field.tomselect) field.tomselect.setValue("cutout")
      else field.value = "cutout"
      field.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.shapeValue = "cutout"
    this.setAdjustment("fit", "contain")
    this.setAdjustment("shadow", 24)
    this.render()
  }

  toggleBackground() {
    if (this.processing) return
    if (this.adjustment("remove_background", 0) === 1) {
      this.cancelBackground()
      this.setAdjustment("remove_background", 0)
      this.imageTarget.src = this.originalUrlValue
      this.backgroundButtonTarget.textContent = "Remover fundo"
      this.backgroundStatusTarget.textContent = "Imagem original restaurada na prévia. Salve para aplicar."
    } else this.loadBackground()
  }

  cancelBackground() {
    clearTimeout(this.backgroundTimer)
    clearTimeout(this.backgroundDeadline)
    this.backgroundRequest = (this.backgroundRequest || 0) + 1
    this.processing = false
  }

  loadBackground() {
    if (!this.cutoutUrlValue || !this.hasBackgroundButtonTarget) return
    this.cancelBackground()
    const request = this.backgroundRequest
    this.processing = true
    this.backgroundButtonTarget.disabled = true
    this.backgroundButtonTarget.textContent = "Recortando…"
    this.backgroundStatusTarget.textContent = "Preparando a imagem sem fundo. A primeira prévia pode levar alguns segundos."
    let attempt = 0
    const failed = () => {
      if (request !== this.backgroundRequest) return
      this.cancelBackground()
      this.imageTarget.src = this.originalUrlValue
      this.backgroundButtonTarget.disabled = false
      this.backgroundButtonTarget.textContent = this.adjustment("remove_background", 0) === 1 ? "Restaurar fundo original" : "Tentar recorte novamente"
      this.backgroundStatusTarget.textContent = "O recorte não ficou disponível. Verifique o recurso e os créditos no Cloudinary ou envie um PNG/WebP sem fundo. O original foi mantido."
    }
    this.backgroundDeadline = setTimeout(failed, 25000)
    const load = () => {
      const preview = new Image()
      preview.onload = () => {
        if (request !== this.backgroundRequest) return
        clearTimeout(this.backgroundDeadline)
        this.processing = false
        this.imageTarget.src = this.cutoutUrlValue
        this.setAdjustment("remove_background", 1)
        this.backgroundButtonTarget.disabled = false
        this.backgroundButtonTarget.textContent = "Restaurar fundo original"
        this.backgroundStatusTarget.textContent = "Confira o contorno na prévia. O recorte será aplicado ao salvar; o arquivo original continua disponível."
      }
      preview.onerror = () => {
        if (request !== this.backgroundRequest) return
        if (++attempt < 5) { this.backgroundTimer = setTimeout(load, attempt * 1500); return }
        failed()
      }
      preview.src = this.cutoutUrlValue
    }
    load()
  }

  flip(event) {
    const key = event.currentTarget.dataset.flip
    const field = this.adjustmentTargets.find(input => input.dataset.adjustment === key)
    field.value = -Number(field.value)
    event.currentTarget.setAttribute("aria-pressed", Number(field.value) === -1)
    this.render()
  }

  filter(event) {
    const preset = { natural: [100, 100, 100], mono: [100, 110, 0], soft: [108, 90, 85] }[event.currentTarget.dataset.filter]
    ;["brightness", "contrast", "saturation"].forEach((key, index) => {
      this.adjustmentTargets.find(input => input.dataset.adjustment === key).value = preset[index]
    })
    this.render()
  }

  imageFailed() {
    if (this.originalUrlValue && this.imageTarget.src !== new URL(this.originalUrlValue, document.baseURI).href) {
      this.imageTarget.src = this.originalUrlValue
      this.errorTarget.textContent = "A prévia processada não está disponível; exibindo a imagem original."
    }
  }

  loaded() {
    this.dimensionsTarget.textContent = `Original: ${this.imageTarget.naturalWidth} × ${this.imageTarget.naturalHeight} px · arraste dentro da moldura para enquadrar`
  }

  fileChanged() {
    const file = this.fileTarget.files?.[0]
    if (!file) return
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      this.errorTarget.textContent = "Escolha uma imagem JPG, PNG ou WebP."
      this.fileTarget.value = ""
      return
    }
    if (file.size > 10 * 1024 * 1024) {
      this.errorTarget.textContent = "Escolha uma imagem de até 10 MB."
      this.fileTarget.value = ""
      return
    }
    this.errorTarget.textContent = ""
    this.cancelBackground()
    const defaults = { rotation: 0, brightness: 100, contrast: 100, saturation: 100, flip_x: 1, flip_y: 1, shadow: 0, remove_background: 0, fit: "cover" }
    this.adjustmentTargets.forEach(input => {
      if (input.tomselect) input.tomselect.setValue(defaults[input.dataset.adjustment], true)
      else input.value = defaults[input.dataset.adjustment]
    })
    if (this.hasBackgroundButtonTarget) {
      this.backgroundButtonTarget.disabled = true
      this.backgroundButtonTarget.textContent = "Remover fundo"
      this.backgroundStatusTarget.textContent = "Salve a nova imagem para habilitar o recorte por IA."
    }
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = URL.createObjectURL(file)
    this.imageTarget.src = this.objectUrl
    this.imageTarget.classList.remove("is-hidden")
    this.emptyTarget.classList.add("is-hidden")
    this.reset()
  }

  shapeChanged() {
    this.shapeValue = this.shapeTarget.value
    this.render()
  }

  start(event) {
    if (event.target.closest(".cms-video")) return
    if (!this.imageTarget.naturalWidth) return
    event.preventDefault()
    const overflow = this.cropOverflow()
    if (!overflow) return
    this.drag = { clientX: event.clientX, clientY: event.clientY, x: Number(this.xTarget.value), y: Number(this.yTarget.value),
      overflowX: overflow.x, overflowY: overflow.y }
    this.frameTarget.setPointerCapture(event.pointerId)
    this.frameTarget.classList.add("is-dragging")
  }

  move(event) {
    if (!this.drag) return
    const axes = []
    if (Math.abs(event.clientX - this.drag.clientX) > 3) axes.push("x")
    if (Math.abs(event.clientY - this.drag.clientY) > 3) axes.push("y")
    if (this.ensurePanSpace(axes)) {
      const overflow = this.cropOverflow()
      this.drag.overflowX = overflow.x
      this.drag.overflowY = overflow.y
    }
    const { clientX, clientY, x, y, overflowX, overflowY } = this.drag
    if (Math.abs(overflowX) > 0.5) this.xTarget.value = this.clamp(x - (event.clientX - clientX) * 100 / overflowX)
    if (Math.abs(overflowY) > 0.5) this.yTarget.value = this.clamp(y - (event.clientY - clientY) * 100 / overflowY)
    this.changed()
  }

  stop(event) {
    this.drag = null
    this.frameTarget.classList.remove("is-dragging")
    if (this.frameTarget.hasPointerCapture(event.pointerId)) this.frameTarget.releasePointerCapture(event.pointerId)
  }

  changed(event) {
    const axis = ["x", "y"].find(key => event?.currentTarget === this[`${key}Target`])
    if (axis) this.ensurePanSpace([axis])
    if (event?.currentTarget === this.zoomTarget) this.positionHint("")
    for (const key of ["x", "y", "zoom"]) this[`${key}FieldTarget`].value = this[`${key}Target`].value
    this.render()
  }

  cropOverflow() {
    const width = this.frameTarget.clientWidth, height = this.frameTarget.clientHeight
    const naturalWidth = this.imageTarget.naturalWidth, naturalHeight = this.imageTarget.naturalHeight
    if (!width || !height || !naturalWidth || !naturalHeight) return null
    const cover = Math[this.setting("fit", "cover") === "contain" ? "min" : "max"](width / naturalWidth, height / naturalHeight)
    const zoom = Number(this.zoomTarget.value)
    return { x: naturalWidth * cover * zoom - width, y: naturalHeight * cover * zoom - height }
  }

  ensurePanSpace(axes) {
    if (Number(this.zoomTarget.value) < 1 || this.setting("fit", "cover") === "contain") return false
    const overflow = this.cropOverflow()
    // object-position cannot move an image along an axis that fits the frame exactly.
    // Only expand on an explicit positioning gesture; opening/resetting a crop stays at 100%.
    if (!overflow || !axes.some(axis => overflow[axis] <= 0.5)) return false
    const zoom = Number(this.zoomTarget.value)
    const nextZoom = Math.min(Number(this.zoomTarget.max), Math.max(1.15, zoom))
    if (nextZoom <= zoom) return false
    this.zoomTarget.value = nextZoom
    this.positionHint(`Zoom ajustado para ${Math.round(nextZoom * 100)}% para permitir o movimento sem deixar bordas vazias.`)
    return true
  }

  positionHint(message) {
    this.positionHintTarget.textContent = message
    this.positionHintTarget.hidden = !message
  }

  reset() {
    this.positionHint("")
    this.xTarget.value = 50
    this.yTarget.value = 50
    this.zoomTarget.value = 1
    this.changed()
  }

  inherit() {
    this.positionHint("")
    for (const key of ["x", "y", "zoom"]) {
      const fieldName = this[`${key}FieldTarget`].name.replace(/\[responsive_settings\]\[(tablet|mobile)\]/, "")
      const baseField = this.form.querySelector(`[name="${fieldName}"]`)
      this[`${key}Target`].value = baseField?.value || this[`${key}Value`]
      this[`${key}FieldTarget`].value = ""
    }
    this.render()
  }

  render() {
    const x = Number(this.xTarget.value), y = Number(this.yTarget.value), zoom = Number(this.zoomTarget.value)
    const shape = this.hasShapeTarget ? this.shapeTarget.value : this.shapeValue
    const radius = { rectangle: "0", rounded: "24px", square: "4px", circle: "50%", oval: "50%", arch: "50% 50% 16px 16px", cutout: "0" }[shape]
    const ratio = ["square", "circle"].includes(shape) ? "1 / 1" :
      (this.kindValue === "banner" ? "1920 / 760" : (this.kindValue === "card" && !["oval", "arch"].includes(shape) ? "16 / 10" : "4 / 5"))
    if (this.cardPreviewValue) {
      this.frameTarget.closest(".compact-card").style.setProperty("--card-image-radius", radius)
    } else {
      this.frameTarget.style.borderRadius = radius
      this.frameTarget.style.aspectRatio = ratio
    }
    this.frameTarget.dataset.shape = shape
    Object.assign(this.imageTarget.style, { objectFit: this.setting("fit", "cover"), objectPosition: `${x}% ${y}%`, transform: `scale(${zoom}) rotate(${this.adjustment("rotation", 0)}deg) scale(${this.adjustment("flip_x", 1)}, ${this.adjustment("flip_y", 1)})`, filter: `brightness(${this.adjustment("brightness", 100)}%) contrast(${this.adjustment("contrast", 100)}%) saturate(${this.adjustment("saturation", 100)}%) drop-shadow(0px 12px 16px rgba(20, 35, 28, ${this.adjustment("shadow", 0) / 100}))`, transformOrigin: `${x}% ${y}%` })
    this.xLabelTarget.value = `${Math.round(x)}%`
    this.yLabelTarget.value = `${Math.round(y)}%`
    this.zoomLabelTarget.value = `${Math.round(zoom * 100)}%`
    if (this.hasShadowLabelTarget) this.shadowLabelTarget.value = `${this.adjustment("shadow", 0)}%`
    if (this.cardPreviewValue) this.dispatch("changed")
  }

  clamp(value) { return Math.max(0, Math.min(100, value)) }
}
