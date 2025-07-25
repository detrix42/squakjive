import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

static values = {
    circleId: {
      type: Number
    },
    userId: {
      type: Number
    }
  }

  async remove_member() {
    const url = '/circle_memberships'
    const data = {circle_membership: {
        circle_id: this.circleIdValue,
        user_id: this.userIdValue
      }
    }
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    if (confirm('Are you sure you want to remove this user from this circle?')) {
      try {
        const res = await fetch(url, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/vnd.turbo-stream.html',
            'X-CSRF-Token': csrfToken
          },
          body: JSON.stringify(data)
        })
        if (res.ok) {
          const resText = await res.text()
          console.log('resText:', resText)
          Turbo.renderStreamMessage(resText)

          const user_to_remove =
              document.querySelector(`#sidebar-user-item-${this.userIdValue}`)
          user_to_remove.remove()

        } else {
          alert('Error removing user from circle')
        }
      } catch (error) {
        alert('Network error removing user from circle')
      }

    }
  }

}
