import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["method"]

  connect() {
    // Small delay to ensure DOM is ready
    setTimeout(() => {
      this.toggleFields()
    }, 100)
  }

  toggleFields() {
    const method = this.methodTarget.value
    console.log('Depreciation method:', method) // Debug log
    
    // Hide all depreciation fields first
    document.querySelectorAll('.depreciation-fields').forEach(field => {
      field.classList.add('hidden')
    })
    
    // Show relevant fields based on selected method
    const usefulLifeField = document.getElementById('useful-life-field')
    const depreciationRateField = document.getElementById('depreciation-rate-field')
    const salvageValueField = document.getElementById('salvage-value-field')
    const doubleDeclineNote = document.getElementById('double-declining-note')
    
    switch(method) {
      case 'straight_line':
        if (usefulLifeField) {
          usefulLifeField.classList.remove('hidden')
          console.log('Showing useful life field for straight line')
        }
        if (salvageValueField) {
          salvageValueField.classList.remove('hidden')
          console.log('Showing salvage value field')
        }
        break
        
      case 'declining_balance':
        if (depreciationRateField) {
          depreciationRateField.classList.remove('hidden')
          console.log('Showing depreciation rate field')
        }
        if (salvageValueField) {
          salvageValueField.classList.remove('hidden')
          console.log('Showing salvage value field')
        }
        if (doubleDeclineNote) {
          doubleDeclineNote.classList.add('hidden')
        }
        break
        
      case 'double_declining':
        if (usefulLifeField) {
          usefulLifeField.classList.remove('hidden')
          console.log('Showing useful life field for double declining')
        }
        if (depreciationRateField) {
          depreciationRateField.classList.remove('hidden')
          console.log('Showing depreciation rate field')
        }
        if (salvageValueField) {
          salvageValueField.classList.remove('hidden')
          console.log('Showing salvage value field')
        }
        if (doubleDeclineNote) {
          doubleDeclineNote.classList.remove('hidden')
        }
        
        // Auto-calculate depreciation rate for double declining
        this.setupDoubleDeclineCalculation()
        break
    }
  }

  setupDoubleDeclineCalculation() {
    const lifeField = document.querySelector('#user_asset_useful_life_years')
    const rateField = document.querySelector('#user_asset_depreciation_rate')
    
    if (lifeField && rateField) {
      // Calculate initial rate if life is already filled
      if (lifeField.value) {
        const rate = (2 / parseFloat(lifeField.value)) * 100
        rateField.value = rate.toFixed(2)
      }
      rateField.readOnly = true
      
      // Add event listener to update rate when life changes
      lifeField.addEventListener('input', function() {
        if (this.value && rateField) {
          const rate = (2 / parseFloat(this.value)) * 100
          rateField.value = rate.toFixed(2)
        }
      })
    }
  }
}