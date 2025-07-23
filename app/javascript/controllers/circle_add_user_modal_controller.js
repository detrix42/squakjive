import {Controller} from "@hotwired/stimulus"
import {Modal} from "bootstrap"

export default class extends Controller {
  connect() {
    this.modal = new Modal(this.element)
    this.modal.show()
  }

  disconnect() {
    this.modal.hide()
  }

  close() {
    console.log('close add user modal')
    if (this.modal) {
      this.modal.hide()
    }
    this.element.innerHTML = ""
  }


  async addUserToCircle(event) {
    event.preventDefault()
    const userId = event.currentTarget.dataset.userId
    const circleId = document.querySelector('.circle-item.selected').dataset.circlesCircleId

    console.log("Adding user", userId, "to circle", circleId)
    try {
      const res = await fetch(`/circles/${circleId}/add_user`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({user_id: userId})
      })

      if (res.ok) {
        const resText = await res.text()
        Turbo.renderStreamMessage(resText)
        setTimeout(() => {
          const userCount = document.querySelector('.list-group-item')
          if (userCount === null) {
            this.close()
          }
        }, 100)
      } else {
        alert('Error adding user to circle')
        this.close()
      }
    } catch (error) {
      console.log('network error-> add user error:', error)
      alert('Network error adding user to circle')
    }
  }
}
