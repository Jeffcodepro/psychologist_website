import { Controller } from "@hotwired/stimulus"
import { youtubeId, videoPreview } from "lib/video_media"

export default class extends Controller {
  static targets = ["source", "youtube", "file", "imagePanel", "videoPanel", "uploadFields", "youtubeFields", "preview", "status", "frameFields"]
  static values = { card: Boolean, url: String }

  connect() {
    this.device = "desktop"
    this.onFormChange = () => this.refresh()
    this.form = this.element.closest("form")
    this.onSubmit = event => {
      const total = Array.from(this.form.querySelectorAll('input[type="file"]:not(:disabled)')).reduce((sum, input) => sum + Array.from(input.files).reduce((bytes, file) => bytes + file.size, 0), 0)
      if (total > 60 * 1024 * 1024) {
        event.preventDefault()
        this.statusTarget.textContent = "O total de arquivos ultrapassa 60 MB. Envie menos arquivos neste salvamento."
        this.statusTarget.scrollIntoView({block: "center"})
      }
    }
    this.form?.addEventListener("submit", this.onSubmit)
    this.form?.addEventListener("input", this.onFormChange)
    this.form?.addEventListener("change", this.onFormChange)
    this.refresh()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.onSubmit)
    this.form?.removeEventListener("input", this.onFormChange)
    this.form?.removeEventListener("change", this.onFormChange)
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    cancelAnimationFrame(this.frame)
  }

  fileChanged() {
    this.fileTarget.setCustomValidity("")
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
    const file = this.fileTarget.files[0]
    if (file && (!["video/mp4", "video/webm"].includes(file.type) || file.size > 20 * 1024 * 1024)) {
      this.fileTarget.setCustomValidity("Escolha MP4 ou WebM de até 20 MB.")
      this.fileTarget.reportValidity()
    } else if (file) this.objectUrl = URL.createObjectURL(file)
    this.refresh()
  }

  refresh() {
    if (!this.hasSourceTarget) return
    const source = this.sourceTarget.value
    const isVideo = source !== "image"
    this.element.classList.toggle("is-video", isVideo)
    this.element.classList.toggle("is-card", this.cardValue)
    this.videoPanelTarget.hidden = !isVideo
    this.imagePanelTarget.hidden = isVideo && !this.cardValue
    this.imagePanelTarget.querySelectorAll('input[type="file"]').forEach(input => { input.disabled = isVideo })
    this.fileTarget.disabled = source !== "upload"
    this.uploadFieldsTarget.hidden = source !== "upload"
    this.youtubeFieldsTarget.hidden = source !== "youtube"
    const id = source === "youtube" ? youtubeId(this.youtubeTarget.value) : null
    const url = source === "upload" && this.fileTarget.validity.valid ? (this.objectUrl || this.urlValue) : null
    this.youtubeTarget.setCustomValidity(source === "youtube" && !id ? "Cole um link válido do YouTube." : "")
    this.statusTarget.textContent = !isVideo ? "" : (source === "youtube" ? (id ? "Prévia do vídeo. Toque em reproduzir para conferir." : "Cole um link válido do YouTube para ver a prévia.") : (url ? "Prévia do arquivo selecionado." : "Selecione um arquivo para ver a prévia."))
    const frame = this.cardValue ? this.element.querySelector(".compact-card__image-frame") : this.previewTarget
    if (!frame) return
    const signature = `${source}:${id || ""}:${url || ""}`
    if (this.signature !== signature) {
      frame.querySelector(".cms-video")?.remove()
      if (isVideo && (id || url)) frame.append(videoPreview({ youtube: id, url }))
      this.signature = signature
    }
    const video = frame.querySelector(".cms-video")
    if (video) {
      video.dataset.previewDevice = this.device
      for (const device of ["desktop", "tablet", "mobile"]) {
        for (const [key, fallback] of [["fit", "contain"], ["zoom", "1"], ["x", "50"], ["y", "50"]]) {
          const own = this.element.querySelector(`[data-video-setting="${key}"][data-device="${device}"]`)
          const base = this.element.querySelector(`[data-video-setting="${key}"][data-device="desktop"]`)
          const value = own?.value || base?.value || fallback
          video.style.setProperty(`--video-${device}-${key}`, value + (["x", "y"].includes(key) ? "%" : ""))
        }
      }
    }
    // Run after the card controller has processed the same form event.
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => {
      const image = frame.querySelector(".compact-card__image")
      if (image) image.hidden = isVideo
      if (this.cardValue && isVideo) {
        const card = frame.closest(".compact-card")
        card.classList.toggle("compact-card--with-image", Boolean(video))
        card.querySelector(".compact-card__media").hidden = !video
      }
    })
  }

  syncCardDevice(event) {
    const button = event.target.closest('.card-editor-preview button[data-device]')
    if (button) { this.device = button.dataset.device; this.updateDevice() }
  }

  deviceChanged(event) { this.device = event.currentTarget.dataset.device; this.updateDevice() }

  updateDevice() {
    const cardPreview = this.element.querySelector('.card-editor-preview')
    if (cardPreview) {
      cardPreview.dataset.device = this.device
      cardPreview.querySelectorAll('button[data-device]').forEach(button => button.setAttribute("aria-pressed", button.dataset.device === this.device))
    }
    this.element.querySelectorAll('.media-input__framing button[data-device]').forEach(button => button.setAttribute("aria-pressed", button.dataset.device === this.device))
    this.frameFieldsTargets.forEach(panel => { panel.hidden = panel.dataset.device !== this.device })
    this.refresh()
  }
}
