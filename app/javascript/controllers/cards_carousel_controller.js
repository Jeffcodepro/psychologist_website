import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "viewport",
    "track"
  ]

  static values = {
    autoplay: {
      type: Boolean,
      default: true
    },

    delay: {
      type: Number,
      default: 5000
    }
  }

  connect() {
    this.timer = null

    this.handleVisibilityChange =
      this.handleVisibilityChange.bind(this)

    document.addEventListener(
      "visibilitychange",
      this.handleVisibilityChange
    )

    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()

    document.removeEventListener(
      "visibilitychange",
      this.handleVisibilityChange
    )
  }

  next() {
    this.move(1)

    this.restartAutoplay()
  }

  previous() {
    this.move(-1)

    this.restartAutoplay()
  }

  move(direction) {
    if (!this.hasViewportTarget) {
      return
    }

    const viewport =
      this.viewportTarget

    const step =
      this.cardStep()

    if (!step) {
      return
    }

    const maxScroll =
      viewport.scrollWidth -
      viewport.clientWidth

    const nearEnd =
      viewport.scrollLeft >=
      maxScroll - 8

    const nearStart =
      viewport.scrollLeft <= 8


    // ---------------------------------------------
    // NEXT AT END
    // ---------------------------------------------

    if (
      direction > 0 &&
      nearEnd
    ) {
      viewport.scrollTo({
        left: 0,
        behavior: "smooth"
      })

      return
    }


    // ---------------------------------------------
    // PREVIOUS AT START
    // ---------------------------------------------

    if (
      direction < 0 &&
      nearStart
    ) {
      viewport.scrollTo({
        left: maxScroll,
        behavior: "smooth"
      })

      return
    }


    viewport.scrollBy({
      left:
        step * direction,

      behavior:
        "smooth"
    })
  }

  cardStep() {
    if (!this.hasTrackTarget) {
      return 0
    }

    const firstCard =
      this.trackTarget.querySelector(
        ".psychology-card"
      )

    if (!firstCard) {
      return 0
    }

    const styles =
      window.getComputedStyle(
        this.trackTarget
      )

    const gap =
      parseFloat(
        styles.columnGap ||
        styles.gap ||
        "0"
      )

    return (
      firstCard.getBoundingClientRect().width +
      gap
    )
  }

  pause() {
    this.stopAutoplay()
  }

  resume() {
    this.startAutoplay()
  }

  startAutoplay() {
    if (!this.autoplayValue) {
      return
    }

    if (document.hidden) {
      return
    }

    this.stopAutoplay()

    this.timer =
      window.setInterval(
        () => {
          this.move(1)
        },
        this.delayValue
      )
  }

  stopAutoplay() {
    if (!this.timer) {
      return
    }

    window.clearInterval(
      this.timer
    )

    this.timer = null
  }

  restartAutoplay() {
    this.stopAutoplay()
    this.startAutoplay()
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stopAutoplay()
    } else {
      this.startAutoplay()
    }
  }
}
