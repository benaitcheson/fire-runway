import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "allocation", "capitalReturn", "dividendYield", "totalReturn",
    "totalAllocation", "blendedReturn", "blendedYield", "blendedTotal",
    "hiddenReturn", "hiddenYield"
  ]

  calculate() {
    let totalAlloc = 0
    let weightedReturn = 0
    let weightedYield = 0

    this.allocationTargets.forEach((allocInput, i) => {
      const alloc = parseFloat(allocInput.value) || 0
      const capReturn = parseFloat(this.capitalReturnTargets[i].value) || 0
      const divYield = parseFloat(this.dividendYieldTargets[i].value) || 0
      const weight = alloc / 100.0

      totalAlloc += alloc
      weightedReturn += weight * capReturn
      weightedYield += weight * divYield

      // Update per-row total
      this.totalReturnTargets[i].textContent = (capReturn + divYield).toFixed(1) + "%"
    })

    // Update footer
    this.totalAllocationTarget.textContent = totalAlloc.toFixed(0) + "%"
    this.blendedReturnTarget.textContent = weightedReturn.toFixed(1) + "%"
    this.blendedYieldTarget.textContent = weightedYield.toFixed(1) + "%"
    this.blendedTotalTarget.textContent = (weightedReturn + weightedYield).toFixed(1) + "%"

    // Update hidden fields for form submission
    this.hiddenReturnTarget.value = weightedReturn.toFixed(2)
    this.hiddenYieldTarget.value = weightedYield.toFixed(2)

    // Highlight if allocation doesn't sum to 100
    if (Math.abs(totalAlloc - 100) > 0.1) {
      this.totalAllocationTarget.classList.add("text-red-600")
    } else {
      this.totalAllocationTarget.classList.remove("text-red-600")
    }
  }
}
