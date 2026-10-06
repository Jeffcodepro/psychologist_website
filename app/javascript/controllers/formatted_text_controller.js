import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "toggle", "status"]
  static values = { url: String }

  connect() {
    this.input = this.element.querySelector("textarea")
    this.handleInput = () => { if (this.showing) this.render() }
    this.handleShortcut = event => {
      if ((event.metaKey || event.ctrlKey) && ["b", "i"].includes(event.key.toLowerCase())) {
        event.preventDefault()
        this.apply(event.key.toLowerCase() === "b" ? "bold" : "italic")
      }
    }
    this.input.addEventListener("input", this.handleInput)
    this.input.addEventListener("keydown", this.handleShortcut)
  }

  disconnect() {
    this.request?.abort()
    this.input.removeEventListener("input", this.handleInput)
    this.input.removeEventListener("keydown", this.handleShortcut)
  }

  format(event) { this.apply(event.currentTarget.dataset.format) }

  apply(format) {
    if (this.showing) this.toggle()
    const input = this.input
    let start = input.selectionStart, end = input.selectionEnd
    let selection = input.value.slice(start, end) || "Seu texto"
    let replacement
    const marks = { bold: "**", italic: "*" }
    if (marks[format]) replacement = marks[format] + selection + marks[format]
    else if (format === "link") replacement = `[${selection}](https://exemplo.com)`
    else {
      start = input.value.lastIndexOf("\n", start - 1) + 1
      const newline = input.value.indexOf("\n", end)
      end = newline === -1 ? input.value.length : newline
      selection = input.value.slice(start, end) || "Seu texto"
      replacement = selection.split("\n").map((line, index) => {
        const prefix = { heading: "## ", list: "- ", ordered: `${index + 1}. `, quote: "> " }[format]
        return prefix + line
      }).join("\n")
      if (start > 0 && input.value[start - 2] !== "\n") replacement = "\n" + replacement
    }
    input.setRangeText(replacement, start, end, "select")
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.focus()
  }

  toggle() {
    this.showing = !this.showing
    this.input.hidden = this.showing
    this.previewTarget.hidden = !this.showing
    this.toggleTarget.textContent = this.showing ? "Voltar a escrever" : "Ver formatação"
    this.toggleTarget.setAttribute("aria-pressed", String(this.showing))
    if (this.showing) this.render()
    else this.input.focus()
  }

  async render() {
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    this.statusTarget.textContent = "Preparando prévia…"
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "same-origin", signal: request.signal,
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ text: this.input.value })
      })
      if (!response.ok) throw new Error()
      const data = await response.json()
      if (request.signal.aborted) return
      this.previewTarget.innerHTML = data.html
      this.statusTarget.textContent = "Prévia da formatação. As alterações ainda precisam ser salvas."
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = "Não foi possível atualizar a prévia. Seu texto continua no editor."
    }
  }
}
