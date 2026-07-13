// Replace Turbo's native confirm() with a Tailwind-styled <dialog>.
// Lives in its own module (imported immediately after turbo-rails) so a
// failure in any later import can't leave Turbo running with native confirm.
import "@hotwired/turbo-rails"

function confirmWithDialog(message) {
  return new Promise((resolve) => {
    const dialog = document.createElement("dialog")
    dialog.className = "rounded-lg shadow-xl p-0 w-full max-w-sm backdrop:bg-gray-900/50"
    dialog.innerHTML = `
      <div class="p-6 bg-white rounded-lg">
        <p class="text-gray-800 text-sm mb-6" data-message></p>
        <div class="flex justify-end gap-3">
          <button value="cancel" class="px-4 py-2 text-sm font-medium rounded border border-gray-300 text-gray-700 hover:bg-gray-100">Cancel</button>
          <button value="confirm" class="px-4 py-2 text-sm font-bold rounded bg-red-600 text-white hover:bg-red-700">Confirm</button>
        </div>
      </div>`
    dialog.querySelector("[data-message]").textContent = message
    dialog.querySelector('[value="cancel"]').addEventListener("click", () => dialog.close("cancel"))
    dialog.querySelector('[value="confirm"]').addEventListener("click", () => dialog.close("confirm"))
    dialog.addEventListener("close", () => {
      resolve(dialog.returnValue === "confirm")
      dialog.remove()
    })
    document.body.appendChild(dialog)
    dialog.showModal()
  })
}

if (window.Turbo?.config?.forms) {
  Turbo.config.forms.confirm = confirmWithDialog
} else {
  Turbo.setConfirmMethod(confirmWithDialog)
}

window.__confirmDialogReady = true
