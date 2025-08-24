import {Controller} from "@hotwired/stimulus"
import {Modal} from "bootstrap"

export default class extends Controller {
  static targets = ["userItem", "emptyState"]

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

  applyFilter(event) {
    const query = (event.detail?.query || "").toLowerCase()
    const visible = []

    this.userItemTargets.forEach((el) => {
      const text = (el.textContent || "").toLowerCase()
      const match = !query || text.includes(query)
      el.classList.toggle("d-none", !match)
      if (match) visible.push(el)
    })

    // Clear old markers
    this.userItemTargets.forEach(el => {
      el.classList.remove("first-visible", "last-visible")
    })

    // Mark first/last visible for rounded corners + borders
    if (visible.length > 0) {
      visible[0].classList.add("first-visible")
      visible[visible.length - 1].classList.add("last-visible")
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle("d-none", visible.length !== 0)
    }
  }


  async addUserToCircle(event) {
    event.preventDefault()
    const userId = event.currentTarget.dataset.userId
    const circleId = document.querySelector('.circle-item.selected').dataset.circlesCircleId

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

  async inviteUserToCircle(event) {
    event.preventDefault()
    const userId = event.currentTarget.dataset.userId
    const circleId = document.querySelector('.circle-item.selected').dataset.circlesCircleId

    try {
      const res = await fetch(`/circles/${circleId}/invite_user`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({user_id: userId})
      })

      if (!res.ok) {
        alert('Error sending invite')
        return
      }

      const html = await res.text()
      if (html) Turbo.renderStreamMessage(html)

    } catch (error) {
      console.log('network error-> add user error:', error)
      alert('Network error adding user to circle')
    }
  }




}
