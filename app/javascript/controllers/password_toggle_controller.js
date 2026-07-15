import { Controller } from "@hotwired/stimulus"

// Show/hide a password field's value.
export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const reveal = this.inputTarget.type === "password"
    this.inputTarget.type = reveal ? "text" : "password"
    this.buttonTarget.textContent = reveal ? "Hide" : "Show"
    this.buttonTarget.setAttribute("aria-pressed", reveal)
  }
}
