import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    this.sourceSectionId = null

    this.scrollSpeed = 0
    this.scrollFrame = null

    this.handleGlobalDragOver =
      this.handleGlobalDragOver.bind(this)

    this.autoScrollLoop =
      this.autoScrollLoop.bind(this)

    document.addEventListener(
      "dragover",
      this.handleGlobalDragOver
    )
  }

  disconnect() {
    document.removeEventListener(
      "dragover",
      this.handleGlobalDragOver
    )

    this.stopAutoScroll()
  }

  dragStart(event) {
    event.stopPropagation()

    this.sourceSectionId =
      event.currentTarget
        .dataset
        .sectionId

    event.dataTransfer.setData(
      "text/plain",
      this.sourceSectionId
    )

    event.dataTransfer.effectAllowed =
      "move"

    event.currentTarget
      .closest(
        ".preview-editable-section"
      )
      ?.classList
      .add("is-dragging")

    this.startAutoScroll()
  }

  dragOver(event) {
    if (!this.sourceSectionId) {
      return
    }

    event.preventDefault()

    event.dataTransfer.dropEffect =
      "move"

    event.currentTarget
      .classList
      .add("is-drop-target")
  }

  async drop(event) {
    if (!this.sourceSectionId || this.saving) return

    event.preventDefault()
    event.stopPropagation()

    const target =
      event.currentTarget

    target.classList.remove(
      "is-drop-target"
    )

    const targetId =
      target.dataset.sectionId

    if (
      String(targetId) ===
      String(this.sourceSectionId)
    ) {
      return
    }

    const sourceId = this.sourceSectionId
    this.saving = true
    this.dragEnd()
    try {
      const response =
        await fetch(
          this.urlValue,
          {
            method: "PATCH",
            credentials: "same-origin",
            redirect: "error",

            headers: {
              "Content-Type":
                "application/json",

              Accept:
                "application/json",

              "X-CSRF-Token":
                this.csrfToken
            },

            body: JSON.stringify({
              first_id:
                sourceId,

              second_id:
                targetId
            })
          }
        )

      if (!response.ok) {
        throw new Error(
          "Não foi possível mover a seção."
        )
      }

      window.location.reload()

    } catch (_error) {
      alert("Não foi possível mover a seção. Recarregue a prévia e tente novamente.")
    } finally {
      this.saving = false
    }
  }

  dragEnd() {
    this.stopAutoScroll()

    this.element
      .querySelectorAll(
        ".preview-editable-section"
      )
      .forEach((section) => {
        section.classList.remove(
          "is-dragging",
          "is-drop-target"
        )
      })

    this.sourceSectionId = null
  }

  handleGlobalDragOver(event) {
    if (!this.sourceSectionId) {
      return
    }

    const height =
      window.innerHeight

    const y =
      event.clientY

    const threshold = 130
    const maxSpeed = 26

    if (y < threshold) {
      const intensity =
        1 - y / threshold

      this.scrollSpeed =
        -Math.max(
          5,
          maxSpeed * intensity
        )

      return
    }

    if (
      y >
      height - threshold
    ) {
      const distance =
        height - y

      const intensity =
        1 -
        distance / threshold

      this.scrollSpeed =
        Math.max(
          5,
          maxSpeed * intensity
        )

      return
    }

    this.scrollSpeed = 0
  }

  startAutoScroll() {
    if (this.scrollFrame) {
      return
    }

    this.scrollFrame =
      requestAnimationFrame(
        this.autoScrollLoop
      )
  }

  autoScrollLoop() {
    if (
      this.sourceSectionId &&
      this.scrollSpeed !== 0
    ) {
      window.scrollBy(
        0,
        this.scrollSpeed
      )
    }

    if (this.sourceSectionId) {
      this.scrollFrame =
        requestAnimationFrame(
          this.autoScrollLoop
        )
    } else {
      this.scrollFrame = null
    }
  }

  stopAutoScroll() {
    this.scrollSpeed = 0

    if (this.scrollFrame) {
      cancelAnimationFrame(
        this.scrollFrame
      )

      this.scrollFrame = null
    }
  }

  get csrfToken() {
    return document
      .querySelector(
        'meta[name="csrf-token"]'
      )
      ?.getAttribute("content")
  }
}
