import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "button",
    "status"
  ]

  static values = {
    url: String
  }

  async translate() {
    const form = this.element.querySelector("form")

    if (!form) return

    const titleInput = form.querySelector(
      '[name="section[title]"]'
    )

    const bodyInput = form.querySelector(
      '[name="section[body]"]'
    )

    const titleEnInput = form.querySelector(
      '[name="section[title_en]"]'
    )

    const bodyEnInput = form.querySelector(
      '[name="section[body_en]"]'
    )

    if (!titleInput || !bodyInput) {
      this.showStatus(
        "Não encontrei o conteúdo em português.",
        true
      )

      return
    }

    const title = titleInput.value.trim()
    const body = bodyInput.value.trim()

    if (!title && !body) {
      this.showStatus(
        "Preencha o título ou o conteúdo em português antes de traduzir.",
        true
      )

      return
    }

    this.setLoading(true)

    try {
      const response = await fetch(
        this.urlValue,
        {
          method: "POST",
          headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
            "X-CSRF-Token": this.csrfToken()
          },
          credentials: "same-origin",
          body: JSON.stringify({
            title: title,
            body: body,
            source_title: title,
            source_body: body,
            translation: {
              title: title,
              body: body,
              source_title: title,
              source_body: body
            }
          })
        }
      )

      const data = await response.json()

      if (!response.ok) {
        throw new Error(
          data.error ||
          data.message ||
          "Não foi possível gerar a tradução."
        )
      }

      const translatedTitle =
        data.title_en ||
        data.translated_title ||
        data.translation?.title_en ||
        data.translation?.title

      const translatedBody =
        data.body_en ||
        data.translated_body ||
        data.translation?.body_en ||
        data.translation?.body

      if (titleEnInput && translatedTitle) {
        titleEnInput.value = translatedTitle
        titleEnInput.dispatchEvent(
          new Event("input", {
            bubbles: true
          })
        )
      }

      if (bodyEnInput && translatedBody) {
        bodyEnInput.value = translatedBody
        bodyEnInput.dispatchEvent(
          new Event("input", {
            bubbles: true
          })
        )
      }

      if (!translatedTitle && !translatedBody) {
        throw new Error(
          "A tradução foi recebida, mas o formato da resposta não foi reconhecido."
        )
      }

      this.showStatus(
        "Versão em inglês gerada. Revise o texto antes de salvar."
      )
    } catch (error) {
      this.showStatus(
        error.message ||
        "Não foi possível gerar a tradução.",
        true
      )
    } finally {
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

    const strong = this.buttonTarget.querySelector(
      "strong"
    )

    if (!strong) return

    strong.textContent = loading
      ? "Traduzindo..."
      : "Gerar versão em inglês"
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
