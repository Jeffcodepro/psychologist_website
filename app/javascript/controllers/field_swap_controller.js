import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    this.sourceSectionId = null
    this.sourceField = null

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

  // -----------------------------------------------
  // DRAG START
  // -----------------------------------------------

  dragStart(event) {
    event.stopPropagation()

    const handle =
      event.currentTarget

    this.sourceSectionId =
      handle.dataset.sectionId

    this.sourceField =
      handle.dataset.field

    /*
     * Alguns browsers exigem algum conteúdo
     * no dataTransfer para iniciar o drag.
     * Mas NÃO dependemos dele no dragOver.
     */
    event.dataTransfer.setData(
      "text/plain",
      `${this.sourceSectionId}:${this.sourceField}`
    )

    event.dataTransfer.effectAllowed =
      "move"

    handle.classList.add(
      "is-dragging"
    )

    document.body.classList.add(
      "preview-field-is-dragging"
    )

    this.startAutoScroll()
  }

  // -----------------------------------------------
  // DRAG OVER
  // -----------------------------------------------

  dragOver(event) {
    if (!this.sourceField) {
      return
    }

    const target =
      event.currentTarget

    const targetField =
      target.dataset.field

    /*
     * Título só recebe Título.
     * Texto só recebe Texto.
     * Imagem só recebe Imagem.
     */
    if (
      targetField !==
      this.sourceField
    ) {
      return
    }

    event.preventDefault()
    event.stopPropagation()

    event.dataTransfer.dropEffect =
      "move"

    target.classList.add(
      "is-field-target"
    )
  }

  dragLeave(event) {
    event.currentTarget.classList.remove(
      "is-field-target"
    )
  }

  // -----------------------------------------------
  // DROP
  // -----------------------------------------------

  async drop(event) {
    if (
      !this.sourceSectionId ||
      !this.sourceField
    ) {
      return
    }

    event.preventDefault()
    event.stopPropagation()

    const target =
      event.currentTarget

    target.classList.remove(
      "is-field-target"
    )

    const targetSectionId =
      target.dataset.sectionId

    const targetField =
      target.dataset.field

    if (
      targetField !==
      this.sourceField
    ) {
      return
    }

    if (
      String(targetSectionId) ===
      String(this.sourceSectionId)
    ) {
      return
    }

    try {
      const response =
        await fetch(
          this.urlValue,
          {
            method: "PATCH",

            headers: {
              "Content-Type":
                "application/json",

              Accept:
                "application/json",

              "X-CSRF-Token":
                this.csrfToken
            },

            body: JSON.stringify({
              source_id:
                this.sourceSectionId,

              target_id:
                targetSectionId,

              field:
                this.sourceField
            })
          }
        )

      if (!response.ok) {
        const data =
          await response
            .json()
            .catch(() => ({}))

        throw new Error(
          data.error ||
          "Não foi possível mover este conteúdo."
        )
      }

      window.location.reload()

    } catch (error) {
      alert(error.message)
    }
  }

  // -----------------------------------------------
  // DRAG END
  // -----------------------------------------------

  dragEnd() {
    this.finishDrag()
  }

  finishDrag() {
    this.stopAutoScroll()

    this.element
      .querySelectorAll(
        ".preview-field-tab"
      )
      .forEach((handle) => {
        handle.classList.remove(
          "is-dragging",
          "is-field-target"
        )
      })

    document.body.classList.remove(
      "preview-field-is-dragging"
    )

    this.sourceSectionId = null
    this.sourceField = null
  }

  // -----------------------------------------------
  // AUTOSCROLL
  // -----------------------------------------------

  handleGlobalDragOver(event) {
    if (!this.sourceField) {
      return
    }

    const viewportHeight =
      window.innerHeight

    const pointerY =
      event.clientY

    const threshold = 130
    const maxSpeed = 26

    if (pointerY < threshold) {
      const intensity =
        1 -
        pointerY /
          threshold

      this.scrollSpeed =
        -Math.max(
          5,
          maxSpeed * intensity
        )

      return
    }

    if (
      pointerY >
      viewportHeight -
        threshold
    ) {
      const distance =
        viewportHeight -
        pointerY

      const intensity =
        1 -
        distance /
          threshold

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
      this.sourceField &&
      this.scrollSpeed !== 0
    ) {
      window.scrollBy(
        0,
        this.scrollSpeed
      )
    }

    if (this.sourceField) {
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
