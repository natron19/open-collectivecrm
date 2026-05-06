import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "cancelButton", "angle", "progress"]
  static values  = { url: String }

  generate(event) {
    event.preventDefault()
    const angle = this.angleTargets.find(r => r.checked)?.value || "value"

    this.#setLoading(true)

    this.#abortController = new AbortController()

    fetch(this.urlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept":       "text/vnd.turbo-stream.html"
      },
      body:   JSON.stringify({ angle }),
      signal: this.#abortController.signal
    })
      .then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))
      .catch(err => {
        if (err.name !== "AbortError") throw err
      })
      .finally(() => this.#setLoading(false))
  }

  cancel() {
    this.#abortController?.abort()
    this.#setLoading(false)
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.cancelButtonTarget.classList.toggle("d-none", !loading)

    if (loading) {
      this.buttonTarget.innerHTML =
        `<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Researching...`
      this.progressTarget.innerHTML = ""
    } else {
      this.buttonTarget.innerHTML = "Research and Write Outreach"
    }
  }

  #abortController = null
}
