import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status", "titlePt", "bodyPt", "titleEn", "bodyEn", "textPt", "textEn"]

  static values = {
    url: String
  }

  disconnect() { this.request?.abort() }

  async translate() {
    if (this.loading) return
    const form = this.element.matches("form") ? this.element : this.element.closest("form") || this.element.querySelector("form")
    if (!form) return

    const singleText = this.hasTextPtTarget
    const titleInput = singleText ? this.textPtTarget : this.hasTitlePtTarget ? this.titlePtTarget : form.querySelector('[name$="[title]"]')
    const bodyInput = singleText ? null : this.hasBodyPtTarget ? this.bodyPtTarget : form.querySelector('[name$="[body]"]')
    const titleEnInput = singleText ? this.textEnTarget : this.hasTitleEnTarget ? this.titleEnTarget : form.querySelector('[name$="[title_en]"]')
    const bodyEnInput = singleText ? null : this.hasBodyEnTarget ? this.bodyEnTarget : form.querySelector('[name$="[body_en]"]')
    const title = titleInput?.value.trim() || ""
    const body = bodyInput?.value.trim() || ""
    if (!title && !body) {
      this.showStatus(singleText ? "Preencha o texto do botão antes de traduzir." : "Preencha o título ou o conteúdo em português antes de traduzir.", true)
      return
    }

    const fields = [titleInput, bodyInput, titleEnInput, bodyEnInput].filter(Boolean)
    const originals = fields.map(field => field.value)
    this.loading = true
    this.request = new AbortController()
    this.setLoading(true)
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "same-origin", signal: this.request.signal,
        headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken() },
        body: JSON.stringify({ translation: { title, body } })
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || data.message || "Não foi possível gerar a tradução.")
      const translatedTitle = data.title_en ?? data.translated_title ?? data.translation?.title_en ?? data.translation?.title
      const translatedBody = data.body_en ?? data.translated_body ?? data.translation?.body_en ?? data.translation?.body
      if ((title && (typeof translatedTitle !== "string" || !translatedTitle.trim())) ||
          (body && (typeof translatedBody !== "string" || !translatedBody.trim()))) {
        throw new Error("A tradução retornou um formato inválido. Tente novamente.")
      }
      if (!this.element.isConnected || fields.some((field, index) => field.value !== originals[index])) {
        throw new Error("O texto mudou durante a tradução. Clique novamente para traduzir a versão atual.")
      }
      if (singleText && titleEnInput.maxLength > 0 && translatedTitle.length > titleEnInput.maxLength) {
        throw new Error("A tradução ficou longa demais para o botão. Encurte o texto em português e tente novamente.")
      }
      if (titleEnInput && typeof translatedTitle === "string") {
        titleEnInput.value = translatedTitle
        titleEnInput.dispatchEvent(new Event("input", { bubbles: true }))
      }
      if (bodyEnInput && typeof translatedBody === "string") {
        bodyEnInput.value = translatedBody
        bodyEnInput.dispatchEvent(new Event("input", { bubbles: true }))
      }
      this.showStatus("Versão em inglês gerada. Revise o texto antes de salvar.")
    } catch (error) {
      if (error.name !== "AbortError") this.showStatus(error.message || "Não foi possível gerar a tradução.", true)
    } finally {
      this.loading = false
      this.setLoading(false)
    }
  }

  setLoading(loading) {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = loading

    this.buttonTarget.classList.toggle(
      "is-loading",
      loading
    )

    const label = this.buttonTarget.querySelector("strong") || this.buttonTarget
    if (loading) { this.originalLabel = label.textContent; label.textContent = "Traduzindo…" }
    else if (this.originalLabel) label.textContent = this.originalLabel
  }

  showStatus(message, error = false) {
    if (!this.hasStatusTarget) return

    this.statusTarget.hidden = false
    this.statusTarget.textContent = message

    this.statusTarget.classList.toggle(
      "is-error",
      error
    )

    this.statusTarget.classList.toggle(
      "is-success",
      !error
    )
  }

  csrfToken() {
    const token = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content

    if (token) return token

    try {
      return window.parent.document.querySelector(
        'meta[name="csrf-token"]'
      )?.content || ""
    } catch (_error) {
      return ""
    }
  }
}
