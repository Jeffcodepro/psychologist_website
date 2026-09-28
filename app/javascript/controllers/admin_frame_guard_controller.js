import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.top !== window.self) window.top.location.href = window.location.href
  }
}
