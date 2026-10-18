import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prompt", "model", "response", "submit", "question", "status", "elapsed"]

  disconnect() {
    this.stopSpinner()
  }

  async submit(event) {
    event.preventDefault()

    const prompt = this.promptTarget.value
    const model = this.modelTarget.value

    if (!prompt.trim()) {
      alert("Please enter a question")
      return
    }

    // Disable submit button and show loading state
    this.submitTarget.disabled = true
    this.submitTarget.textContent = "Sending..."

    // Show the question
    this.questionTarget.textContent = prompt
    this.questionTarget.parentElement.classList.remove("hidden")

    // Hide the previous answer and show a spinner until this one arrives
    this.responseTarget.parentElement.classList.add("hidden")
    this.startSpinner()

    try {
      const response = await fetch("/ai_assistant/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: JSON.stringify({ prompt: prompt, model: model })
      })

      const data = await response.json()

      // Display the response
      let responseText = data.response
      if (typeof responseText === 'object') {
        if (responseText.error) {
          responseText = `Error: ${responseText.error}`
        } else {
          responseText = JSON.stringify(responseText, null, 2)
        }
      }
      
      this.responseTarget.textContent = responseText
      this.responseTarget.parentElement.classList.remove("hidden")

    } catch (error) {
      console.error("Error:", error)
      this.responseTarget.textContent = "Error: " + error.message
      this.responseTarget.parentElement.classList.remove("hidden")
    } finally {
      this.stopSpinner()

      // Re-enable submit button
      this.submitTarget.disabled = false
      this.submitTarget.textContent = "Send"
    }
  }

  // Local models can take a while, so count the seconds to show it's still working
  startSpinner() {
    const startedAt = Date.now()
    this.elapsedTarget.textContent = ""
    this.statusTarget.classList.remove("hidden")
    this.timer = setInterval(() => {
      this.elapsedTarget.textContent = `${Math.floor((Date.now() - startedAt) / 1000)}s`
    }, 1000)
  }

  stopSpinner() {
    clearInterval(this.timer)
    this.timer = null
    if (this.hasStatusTarget) this.statusTarget.classList.add("hidden")
  }
}
