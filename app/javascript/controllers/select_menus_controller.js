import { Controller } from "@hotwired/stimulus"
import "tom-select"

// A bounded, searchable list shared by the CMS and public contact forms.
export default class extends Controller {
  connect() {
    this.menus = new Map()
    this.openMenu = null
    this.scan()
    this.observer = new MutationObserver(records => {
      if (records.some(record => record.type === "childList" && !record.target.closest?.(".ts-wrapper, .ts-dropdown"))) this.scheduleScan()
      records.forEach(record => {
        const select = record.target.closest?.("select")
        const menu = this.menus.get(select)
        if (!menu) return
        if (record.attributeName === "disabled") {
          if (select.disabled && !menu.isDisabled) menu.disable()
          else if (!select.disabled && menu.isDisabled) menu.enable()
          if (String(menu.getValue()) !== select.value) menu.setValue(select.value, true)
        }
      })
    })
    this.observer.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: ["disabled"] })
    this.beforeCache = () => this.teardown()
    this.onResize = () => this.positionMenu(this.openMenu)
    this.onScroll = event => {
      if (!this.openMenu || this.openMenu.dropdown.contains(event.target)) return
      this.positionMenu(this.openMenu)
    }
    this.onChange = event => {
      const menu = this.menus.get(event.target)
      if (menu && String(menu.getValue()) !== event.target.value) menu.sync()
    }
    document.addEventListener("turbo:before-cache", this.beforeCache)
    document.addEventListener("scroll", this.onScroll, true)
    this.element.addEventListener("change", this.onChange)
    window.addEventListener("resize", this.onResize)
  }

  scheduleScan() {
    if (this.pendingScan) return
    this.pendingScan = requestAnimationFrame(() => { this.pendingScan = null; this.scan() })
  }

  scan() {
    for (const [select, menu] of this.menus) {
      if (!select.isConnected) { menu.destroy(); this.menus.delete(select) }
    }
    this.element.querySelectorAll("select:not([multiple]):not([data-native-select])").forEach(select => {
      if (select.tomselect || select.closest("template")) return
      const label = select.labels?.[0]
      const english = document.documentElement.lang.startsWith("en")
      const render = { no_results: () => `<div class="no-results">${english ? "No results" : "Nenhuma opção encontrada"}</div>` }
      if (select.hasAttribute("data-phone-country")) {
        render.item = (option, escape) => {
          const flag = /^[A-Z]{2}$/.test(option.value) ? [...option.value].map(letter => String.fromCodePoint(letter.charCodeAt(0) + 127397)).join("") : ""
          const dial = option.text.match(/\+\d+/)?.[0] || option.text
          return `<div title="${escape(option.text)}" aria-label="${escape(option.text)}"><span aria-hidden="true">${escape(flag)}</span> ${escape(dial)}</div>`
        }
      }
      const menu = new window.TomSelect(select, {
        create: false, maxItems: 1, maxOptions: null, allowEmptyOption: true,
        closeAfterSelect: true, dropdownParent: document.body, refreshThrottle: 0,
        plugins: ["dropdown_input"],
        score: query => {
          const normalized = value => value.normalize("NFKD").replace(/\p{M}/gu, "").toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim()
          const terms = normalized(query).split(/\s+/)
          return option => terms.every(term => normalized(option.text).includes(term)) ? 1 : 0
        },
        render,
        onDropdownOpen: () => {
          if (this.openMenu && this.openMenu !== menu) this.openMenu.close()
          this.openMenu = menu
          this.positionMenu(menu)
        },
        onDropdownClose: () => { if (this.openMenu === menu) this.openMenu = null }
      })
      if (label) {
        label.id ||= `${menu.inputId}-label`
        menu.control.setAttribute("aria-labelledby", label.id)
        menu.dropdown_content.setAttribute("aria-labelledby", label.id)
      }
      menu.dropdown.classList.add("selection-menu")
      menu.wrapper.classList.add("selection-control")
      menu.control_input.placeholder = english ? "Search options…" : "Buscar opções…"
      menu.control_input.setAttribute("aria-label", english ? "Search options" : "Buscar opções")
      menu.positionDropdown = () => this.positionMenu(menu)
      this.menus.set(select, menu)
    })
  }

  positionMenu(menu) {
    if (!menu?.isOpen) return
    const rect = menu.control.getBoundingClientRect()
    const viewport = window.innerHeight
    const below = viewport - rect.bottom - 12
    const above = rect.top - 12
    const upwards = below < 220 && above > below
    const height = Math.min(320, Math.max(100, upwards ? above : below))
    Object.assign(menu.dropdown.style, {
      position: "fixed", left: `${Math.max(8, Math.min(rect.left, window.innerWidth - rect.width - 8))}px`,
      width: `${Math.min(rect.width, window.innerWidth - 16)}px`,
      top: upwards ? "auto" : `${rect.bottom + 6}px`,
      bottom: upwards ? `${viewport - rect.top + 6}px` : "auto", margin: "0"
    })
    menu.dropdown_content.style.maxHeight = `${height - 55}px`
  }

  teardown() {
    this.observer?.disconnect()
    if (this.pendingScan) cancelAnimationFrame(this.pendingScan)
    this.menus?.forEach(menu => menu.destroy())
    this.menus?.clear()
    this.openMenu = null
  }

  disconnect() {
    this.teardown()
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.removeEventListener("scroll", this.onScroll, true)
    this.element.removeEventListener("change", this.onChange)
    window.removeEventListener("resize", this.onResize)
  }
}
