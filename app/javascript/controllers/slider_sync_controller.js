import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "number"]

  syncToNumber() {
    this.numberTarget.value = this.sliderTarget.value
  }

  syncToSlider() {
    this.sliderTarget.value = this.numberTarget.value
  }
}
