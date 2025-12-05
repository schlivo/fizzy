import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = [ "select", "accountSelect" ]
  static outlets = [ "user-select" ]

  async selectBoard(event) {
    const boardId = event?.target?.value
    
    if (!boardId) {
      return
    }

    try {
      const response = await get(`/admin/api_tokens/board_info?board_id=${boardId}`, {
        responseKind: "json"
      })

      if (response.ok) {
        const boardInfo = await response.json
        
        // Set the account select to the board's account
        if (this.hasAccountSelectTarget) {
          this.accountSelectTarget.value = boardInfo.account_id
          
          // Wait a bit for the DOM to update, then trigger change
          await new Promise(resolve => setTimeout(resolve, 100))
          
          // Trigger both input and change events to ensure compatibility
          const inputEvent = new Event('input', { bubbles: true, cancelable: true })
          const changeEvent = new Event('change', { bubbles: true, cancelable: true })
          this.accountSelectTarget.dispatchEvent(inputEvent)
          this.accountSelectTarget.dispatchEvent(changeEvent)
          
          // Also try to manually find and trigger user-select controller
          const userSelectElement = this.element.querySelector('[data-controller*="user-select"]')
          if (userSelectElement) {
            const userSelectController = this.application.getControllerForElementAndIdentifier(
              userSelectElement,
              'user-select'
            )
            if (userSelectController && userSelectController.hasSelectTarget) {
              // Manually trigger loadUsers
              await userSelectController.loadUsers({ target: this.accountSelectTarget })
            }
          }
        }
      }
    } catch (error) {
      console.error("Error loading board info:", error)
    }
  }
}

