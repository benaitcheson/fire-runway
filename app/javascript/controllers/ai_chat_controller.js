import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prompt", "model", "response", "submit", "question"]

  connect() {
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
      this.responseTarget.textContent = data.response
      this.responseTarget.parentElement.classList.remove("hidden")

    } catch (error) {
      console.error("Error:", error)
      this.responseTarget.textContent = "Error: " + error.message
      this.responseTarget.parentElement.classList.remove("hidden")
    } finally {
      // Re-enable submit button
      this.submitTarget.disabled = false
      this.submitTarget.textContent = "Send"
    }
  }
}