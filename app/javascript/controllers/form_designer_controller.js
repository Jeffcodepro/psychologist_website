import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value", "list", "template", "status"]

  connect() {
    this.fields = JSON.parse(this.valueTarget.value)
    this.render()
    this.onDragOver = event => {
      if (!this.dragged) return
      event.preventDefault()
      const row = event.target.closest("[data-field-row]")
      if (!row || row === this.dragged) return
      const rect = row.getBoundingClientRect()
      row.insertAdjacentElement(event.clientY < rect.top + rect.height / 2 ? "beforebegin" : "afterend", this.dragged)
    }
    this.listTarget.addEventListener("dragover", this.onDragOver)
  }

  disconnect() { this.listTarget.removeEventListener("dragover", this.onDragOver) }

  render() {
    this.listTarget.replaceChildren()
    this.fields.forEach(field => {
      const row = this.templateTarget.content.firstElementChild.cloneNode(true)
      row.dataset.key = field.key
      row.querySelector("[data-field-heading]").textContent = field.label
      row.querySelectorAll("[data-property]").forEach(input => {
        const property = input.dataset.property
        if (property === "required") input.checked = field.required
        else input.value = property === "options" ? (field.options || []).join("\n") : field[property] || ""
      })
      row.querySelector("[data-options-row]").hidden = field.type !== "select"
      this.listTarget.append(row)
    })
    this.save()
  }

  update(event) {
    const row = event.target.closest("[data-field-row]")
    const field = this.fields.find(item => item.key === row.dataset.key)
    const property = event.target.dataset.property
    if (!property) return
    field[property] = property === "required" ? event.target.checked : property === "options" ? event.target.value.split("\n").map(value => value.trim()).filter(Boolean) : event.target.value
    row.querySelector("[data-field-heading]").textContent = field.label
    row.querySelector("[data-options-row]").hidden = field.type !== "select"
    this.save()
  }

  add() {
    if (this.fields.length >= 20) { this.statusTarget.textContent = "Você pode adicionar até 20 campos."; return }
    this.fields.push({ key: `field_${crypto.randomUUID().replaceAll("-", "")}`, label: "Novo campo", label_en: "", type: "text", required: false, width: "full" })
    this.render()
    this.listTarget.lastElementChild.querySelector("input").focus()
  }

  remove(event) {
    if (this.fields.length <= 1) { this.statusTarget.textContent = "Mantenha pelo menos um campo no formulário."; return }
    const key = event.target.closest("[data-field-row]").dataset.key
    this.fields = this.fields.filter(field => field.key !== key)
    this.render()
  }

  up(event) { this.move(event, -1) }
  down(event) { this.move(event, 1) }
  move(event, direction) {
    const key = event.target.closest("[data-field-row]").dataset.key
    const index = this.fields.findIndex(field => field.key === key)
    const next = index + direction
    if (next < 0 || next >= this.fields.length) return
    ;[this.fields[index], this.fields[next]] = [this.fields[next], this.fields[index]]
    this.render()
    this.listTarget.querySelector(`[data-key="${key}"] .form-designer__handle`).focus()
  }

  start(event) {
    this.dragged = event.target.closest("[data-field-row]")
    event.dataTransfer.setData("text/plain", this.dragged.dataset.key)
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setDragImage(this.dragged, 20, 20)
    this.dragged.classList.add("is-dragging")
  }
  end() {
    this.dragged?.classList.remove("is-dragging")
    this.fields = Array.from(this.listTarget.children).map(row => this.fields.find(field => field.key === row.dataset.key))
    this.dragged = null
    this.save()
  }
  save() { this.valueTarget.value = JSON.stringify(this.fields) }
}
