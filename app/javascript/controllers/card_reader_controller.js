import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["excerpt", "title", "body", "summary", "button", "dialog"]
  static values = { truncated: Boolean }

  connect() {
    this.observer = new ResizeObserver(() => this.refresh())
    this.observer.observe(this.bodyTarget)
    this.observer.observe(this.titleTarget)
    this.refresh()
    document.fonts?.ready.then(() => { if (this.element.isConnected) this.refresh() })
  }

  disconnect() {
    this.observer?.disconnect()
    cancelAnimationFrame(this.frame)
    if (this.hasDialogTarget) this.dialogTarget.close()
  }

  refresh() {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => this.fit())
  }

  fit() {
    const body = this.bodyTarget, summary = this.summaryTarget
    const style = getComputedStyle(body)
    const available = Math.max(0, body.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom))
    const lineHeight = parseFloat(getComputedStyle(summary).lineHeight)
    const lines = Math.max(0, Math.floor(available / lineHeight))
    summary.style.setProperty("--card-summary-lines", Math.max(1, lines))
    summary.style.visibility = lines ? "visible" : "hidden"
    const clipped = this.truncatedValue || (summary.textContent.trim() && (!lines || summary.scrollHeight > summary.clientHeight + 1)) || this.titleTarget.scrollHeight > this.titleTarget.clientHeight + 1
    const linked = this.element.querySelector(".compact-card__link:not([hidden])")
    if (this.hasButtonTarget) this.buttonTarget.hidden = Boolean(linked) || !clipped
  }

  open() { if (this.hasDialogTarget) this.dialogTarget.showModal() }
  close() { this.dialogTarget.close(); this.buttonTarget.focus() }
  backdrop(event) {
    if (event.target !== this.dialogTarget) return
    const r = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) this.close()
  }
}
