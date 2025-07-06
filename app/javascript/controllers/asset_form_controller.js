import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["priceField", "salvageField", "form"]
  
  connect() {
    this.converted = false
  }

  submit(event) {
    // Prevent double conversion
    if (this.converted) return
    
    // Convert dollars to cents before submitting
    if (this.hasPriceFieldTarget && this.priceFieldTarget.value) {
      const value = parseFloat(this.priceFieldTarget.value)
      if (!isNaN(value)) {
        this.priceFieldTarget.value = Math.round(value * 100)
      }
    }
    
    if (this.hasSalvageFieldTarget && this.salvageFieldTarget.value) {
      const value = parseFloat(this.salvageFieldTarget.value)
      if (!isNaN(value)) {
        this.salvageFieldTarget.value = Math.round(value * 100)
      }
    }
    
    this.converted = true
  }
}