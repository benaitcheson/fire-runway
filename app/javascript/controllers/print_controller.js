import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog, e.g. for the will plan summary.
export default class extends Controller {
  print() {
    window.print()
  }
}
