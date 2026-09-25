import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "image", "empty", "file", "dimensions", "shape", "x", "y", "zoom", "xField", "yField", "zoomField", "xLabel", "yLabel", "zoomLabel", "error", "adjustment"]
  static values = { shape: String, baseShape: String, shapeField: String, kind: String, adjustments: Object, x: Number, y: Number, zoom: Number }

  connect() {
    this.form = this.element.closest("form")
    this.onFormChange = (event) => {
      if (this.kindValue === "banner") return
      if (event.target.name === this.shapeFieldValue) {
        this.shapeValue = event.target.value || this.baseShapeValue
        this.render()
      }
    }
    this.form?.addEventListener("change", this.onFormChange)
    this.render()
    if (this.imageTarget.complete && this.imageTarget.naturalWidth) this.loaded()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onFormChange)
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  choose() { this.fileTarget.click() }

  adjustment(key, fallback) {
    return Number(this.adjustmentTargets.find(input => input.dataset.adjustment === key)?.value ?? this.adjustmentsValue[key] ?? fallback)
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
    this.adjustmentTargets.forEach(input => { input.value = input.dataset.adjustment.startsWith("flip") ? 1 : (input.dataset.adjustment === "rotation" ? 0 : 100) })
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
    if (!this.imageTarget.naturalWidth) return
    event.preventDefault()
    const rect = this.frameTarget.getBoundingClientRect()
    const cover = Math.max(rect.width / this.imageTarget.naturalWidth, rect.height / this.imageTarget.naturalHeight)
    const zoom = Number(this.zoomTarget.value)
    this.drag = { clientX: event.clientX, clientY: event.clientY, x: Number(this.xTarget.value), y: Number(this.yTarget.value),
      overflowX: this.imageTarget.naturalWidth * cover * zoom - rect.width,
      overflowY: this.imageTarget.naturalHeight * cover * zoom - rect.height }
    this.frameTarget.setPointerCapture(event.pointerId)
    this.frameTarget.classList.add("is-dragging")
  }

  move(event) {
    if (!this.drag) return
    const { clientX, clientY, x, y, overflowX, overflowY } = this.drag
    if (overflowX > 0.5) this.xTarget.value = this.clamp(x - (event.clientX - clientX) * 100 / overflowX)
    if (overflowY > 0.5) this.yTarget.value = this.clamp(y - (event.clientY - clientY) * 100 / overflowY)
    this.changed()
  }

  stop(event) {
    this.drag = null
    this.frameTarget.classList.remove("is-dragging")
    if (this.frameTarget.hasPointerCapture(event.pointerId)) this.frameTarget.releasePointerCapture(event.pointerId)
  }

  changed() {
    for (const key of ["x", "y", "zoom"]) this[`${key}FieldTarget`].value = this[`${key}Target`].value
    this.render()
  }

  reset() {
    this.xTarget.value = 50
    this.yTarget.value = 50
    this.zoomTarget.value = 1
    this.changed()
  }

  inherit() {
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
    const radius = { rectangle: "0", rounded: "24px", square: "4px", circle: "50%", oval: "50%", arch: "50% 50% 16px 16px" }[shape]
    const ratio = ["square", "circle"].includes(shape) ? "1 / 1" :
      (this.kindValue === "banner" ? "1920 / 760" : (this.kindValue === "card" && !["oval", "arch"].includes(shape) ? "16 / 10" : "4 / 5"))
    this.frameTarget.style.borderRadius = radius
    this.frameTarget.style.aspectRatio = ratio
    Object.assign(this.imageTarget.style, { objectPosition: `${x}% ${y}%`, transform: `scale(${zoom}) rotate(${this.adjustment("rotation", 0)}deg) scale(${this.adjustment("flip_x", 1)}, ${this.adjustment("flip_y", 1)})`, filter: `brightness(${this.adjustment("brightness", 100)}%) contrast(${this.adjustment("contrast", 100)}%) saturate(${this.adjustment("saturation", 100)}%)`, transformOrigin: `${x}% ${y}%` })
    this.xLabelTarget.value = `${Math.round(x)}%`
    this.yLabelTarget.value = `${Math.round(y)}%`
    this.zoomLabelTarget.value = `${Math.round(zoom * 100)}%`
  }

  clamp(value) { return Math.max(0, Math.min(100, value)) }
}
