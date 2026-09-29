import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["value", "list", "template", "status"]
  connect() {
    this.buttons = JSON.parse(this.valueTarget.value)
    this.render()
    this.dragOver = event => {
      if (!this.dragged) return
      event.preventDefault()
      const row = event.target.closest('[data-button-row]')
      if (!row || row === this.dragged) return
      row.insertAdjacentElement(event.clientY < row.getBoundingClientRect().top + row.offsetHeight / 2 ? 'beforebegin' : 'afterend', this.dragged)
    }
    this.listTarget.addEventListener('dragover', this.dragOver)
  }
  disconnect() { this.listTarget.removeEventListener('dragover', this.dragOver) }
  render() {
    this.listTarget.replaceChildren()
    this.buttons.forEach((button, index) => {
      const row = this.templateTarget.content.firstElementChild.cloneNode(true)
      row.dataset.index = index
      row.querySelectorAll('[data-property]').forEach(input => { input.value = button[input.dataset.property === 'page_value' ? 'value' : input.dataset.property] || '' })
      this.configure(row, button)
      this.listTarget.append(row)
    })
    this.save()
  }
  configure(row, button) {
    row.querySelector('[data-heading]').textContent = button.label
    row.querySelector('[data-page-row]').hidden = button.action !== 'page'
    row.querySelector('[data-destination-row]').hidden = ['contact', 'page'].includes(button.action)
    const input = row.querySelector('[data-property="value"]')
    input.required = !['contact', 'page'].includes(button.action)
    input.type = button.action === 'url' ? 'url' : button.action === 'email' ? 'email' : 'text'
    input.placeholder = { url: 'https://exemplo.com', anchor: '#nome-do-trecho', phone: '+55 11 99999-9999', whatsapp: '+55 11 99999-9999', email: 'contato@exemplo.com' }[button.action] || ''
    row.querySelector('[data-property="page_value"]').required = button.action === 'page'
  }
  update(event) {
    const row = event.target.closest('[data-button-row]')
    const button = this.buttons[Number(row.dataset.index)]
    const property = event.target.dataset.property
    if (!property) return
    button[property === 'page_value' ? 'value' : property] = event.target.value
    if (property === 'action') { button.value = ''; row.querySelector('[data-property="value"]').value = ''; row.querySelector('[data-property="page_value"]').value = '' }
    this.configure(row, button)
    this.save()
  }
  add() {
    if (this.buttons.length >= 8) { this.statusTarget.textContent = 'Limite de oito botões por área.'; return }
    this.buttons.push({ label: 'Saiba mais', label_en: 'Learn more', action: 'contact', value: '', style: 'primary' })
    this.render()
    this.listTarget.lastElementChild.querySelector('input').focus()
  }
  remove(event) { this.buttons.splice(Number(event.target.closest('[data-button-row]').dataset.index), 1); this.render() }
  up(event) { this.move(event, -1) }
  down(event) { this.move(event, 1) }
  move(event, offset) {
    const index = Number(event.target.closest('[data-button-row]').dataset.index)
    const next = index + offset
    if (next < 0 || next >= this.buttons.length) return
    ;[this.buttons[index], this.buttons[next]] = [this.buttons[next], this.buttons[index]]
    this.render()
    this.listTarget.children[next].querySelector('button').focus()
  }
  start(event) { this.dragged = event.target.closest('[data-button-row]'); event.dataTransfer.setData('text/plain', this.dragged.dataset.index); event.dataTransfer.effectAllowed = 'move'; event.dataTransfer.setDragImage(this.dragged, 20, 20) }
  end() { this.buttons = [...this.listTarget.children].map(row => this.buttons[Number(row.dataset.index)]); this.dragged = null; this.render() }
  save() { this.valueTarget.value = JSON.stringify(this.buttons) }
}
